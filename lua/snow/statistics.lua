-- 输入统计处理器与翻译器
--
-- 用法（前缀为方案的 lua/input）：
--   otj   本机、本方案的今日、本周、本月、本年统计，候选注释里是词长和码长分布
--   otjq  所有设备合并的统计（其他设备的数据经 Rime 同步后才会出现）
--   otjs  各设备分别列出，当前设备标「（本机）」
--   otjd  把全部方案、全部设备的数据导出到用户目录下的 snow_statistics.tsv
-- 设备按 installation.yaml 的 installation_id 区分，可改成 macbook、phone 等易读的名字，
-- 但改名后旧数据仍记在旧名字下。
--
-- 各量的含义：
--   字数      上屏的字符数，标点、数字、空格以及没有编码时直接输入的字符都算
--   按键      输入过程中按下的键数，组合键整组算一个，单独按放的修饰键算一个
--   有效按键  按键数减去两倍退格数，即退格和被它删掉的那个键都不算
--   时长      相邻两次按键的间隔之和，超过 5 秒的间隔视为停顿，不计入
--   均速      字数 / 时长，单位为字/分
--   极速      每累计 60 秒时长结算一次分速，取最高值
--   击键      按键 / 时长，单位为键/秒
--   码长      按键 / 字数
--   键准      有效按键 / 按键
--   理论码长  有效按键 / 字数
--   词长分布  每次上屏的字数的分布
--   码长分布  每次上屏所用有效按键数的分布，即上次上屏后到这次上屏的按键，顶功时触发顶屏的键算给下一个词
-- 详细口径和设计取舍见仓库 CLAUDE.md 的「输入统计」一节。

local snow = require "snow.snow"

-- 两次击键间隔超过这个值（毫秒）视为停顿，不计入输入时长
local idle_ms = 5000
-- 每累计这么长的输入时长（毫秒）结算一次分速，取最高值作为极速
local window_ms = 60000
-- 所有方案、所有安装共用一个库，键为「方案 日期 安装 \t字段」，值为 `c=` 格式：这是用户词典快照
-- 的格式，同步时才能原样导出和合并。各安装只写带自己 installation_id 的键，且计数只增不减，
-- 所以合并时 UserDbMerger 取最大值就是该安装的最新值
local db_name = "snow_statistics"

-- 标量字段，也是导出文件的前几列：字数、按键数、有效按键数（编码中每按一次退格减一）、输入时长（毫秒）、极速（字/分）。
-- 此外每次上屏给 word<i>（这次上屏 i 个字）和 code<i>（距上次上屏有 i 个有效按键）各加一，i 不设上限，
-- 所以 Σ i·word<i> = chars，Σ i·code<i> = effective_keys
local columns = { "chars", "keys", "effective_keys", "duration", "fastest" }

---@class StatisticsEnv: Env
---@field db LevelDb|nil
---@field schema_id string
---@field installation string
---@field prompt string
---@field connection Connection
---@field unhandled_connection Connection
---@field property_connection Connection
---@field last integer
---@field tap integer|nil
---@field steps { effective: integer, duration: integer }[]
---@field carry integer
---@field window_chars integer
---@field window_duration integer

---@param db LevelDb
---@param key string
local function fetch(db, key)
  return snow.parse(db:fetch(key) or "") or 0
end

---@param env StatisticsEnv
local function open(env)
  env.schema_id = env.engine.schema.schema_id
  env.installation = rime_api.get_user_id()
  env.db = snow.get_db(db_name)
end

---@param env StatisticsEnv
local function close(env)
  if env.db then
    env.db = nil
    snow.release_db(db_name)
  end
end

local processor = {}

---@param env StatisticsEnv
function processor.init(env)
  open(env)
  env.last = 0
  env.steps = {}
  env.carry = 0
  env.window_chars = 0
  env.window_duration = 0
  local context = env.engine.context
  -- 选词、顶屏、回车上屏编码等经过 context:commit() 的上屏
  env.connection = context.commit_notifier:connect(function(ctx)
    processor.record(env, ctx:get_commit_text(), snow.handover)
  end)
  -- 没有编码时直接放行给应用的可见字符（数字、空格等）记作一字词；popping 重投时放行的键并没有到达应用
  env.unhandled_connection = context.unhandled_key_notifier:connect(function(ctx, key_event)
    local keycode = key_event.keycode
    if snow.redispatching or ctx:get_option("ascii_mode") or key_event:release() or key_event:ctrl()
        or key_event:alt() or key_event:super() or keycode < 0x20 or keycode > 0x7e then
      return
    end
    processor.record(env, string.char(keycode))
  end)
  -- 以词定字、略码等用 snow.commit_text 直接上屏的
  env.property_connection = context.property_update_notifier:connect(function(ctx, name)
    if name == "commit_text" then
      processor.record(env, ctx:get_property(name))
    end
  end)
end

---@param key_event KeyEvent
---@param env StatisticsEnv
function processor.func(key_event, env)
  -- popping 重投的按键已经记过一次
  if snow.redispatching then
    return snow.kNoop
  end
  local context = env.engine.context
  local keycode = key_event.keycode
  local composing = context:is_composing()
  local ascii_mode = context:get_option("ascii_mode")
  -- 修饰键单独按下又松开（如切换临时西文的 Shift）算一个键；和别的键一起按时，整组只算那一个键
  if keycode >= 0xffe1 and keycode <= 0xffee then
    if not key_event:release() then
      env.tap = keycode
      return snow.kNoop
    end
    local tapped = env.tap == keycode
    env.tap = nil
    if not (tapped and composing) then
      return snow.kNoop
    end
  elseif key_event:release() then
    return snow.kNoop
  else
    env.tap = nil
    -- 没有编码时只记直接输入的可见字符，快捷键和全局英文状态下的输入都交给应用，不记
    if not composing and (ascii_mode or key_event:ctrl() or key_event:alt() or key_event:super()
          or keycode < 0x20 or keycode > 0x7e) then
      return snow.kNoop
    end
  end
  local now = rime_api.get_time_ms()
  table.insert(env.steps, {
    effective = keycode == snow.kBackSpace and -1 or 1,
    duration = now - env.last < idle_ms and now - env.last or 0,
  })
  env.last = now
  -- 临时西文由 ascii_composer 用 engine:CommitText 上屏，不经过 commit_notifier，按它的规则在这里补记
  if composing and ascii_mode then
    if keycode == snow.kSpace then
      processor.record(env, context.input .. " ")
    elseif keycode == snow.kReturn then
      processor.record(env, context.input)
    end
  end
  return snow.kNoop
end

--- 把上屏前累计的按键、有效按键和时长，连同这次上屏的字数、词长和码长写进当天的记录
---@param env StatisticsEnv
---@param text string 上屏的文字
---@param handover integer|nil 最后几个按键属于下一个词（顶屏键和推回输入框的编码），不计入这次上屏
function processor.record(env, text, handover)
  local db = env.db
  local chars = utf8.len(text) or 0
  if not db or chars == 0 then
    return
  end
  local prefix = ("%s %s %s \t"):format(env.schema_id, os.date("%Y%m%d"), env.installation)
  local steps = env.steps
  local count = #steps - math.min(handover or 0, #steps)
  local delta = { chars = chars, keys = count, effective_keys = env.carry, duration = 0 }
  for i = 1, count do
    delta.effective_keys = delta.effective_keys + steps[i].effective
    delta.duration = delta.duration + steps[i].duration
  end
  -- 退格多于其余按键时有效按键为负，留到下次上屏再记，保证库里的计数只增不减
  env.carry = math.min(delta.effective_keys, 0)
  delta.effective_keys = delta.effective_keys - env.carry
  delta["word" .. chars] = 1
  delta["code" .. delta.effective_keys] = 1
  for field, value in pairs(delta) do
    db:update(prefix .. field, snow.format(fetch(db, prefix .. field) + value))
  end
  env.window_chars = env.window_chars + chars
  env.window_duration = env.window_duration + delta.duration
  if env.window_duration >= window_ms then
    local speed = math.floor(env.window_chars * 60000 / env.window_duration)
    if speed > fetch(db, prefix .. "fastest") then
      db:update(prefix .. "fastest", snow.format(speed))
    end
    env.window_chars = 0
    env.window_duration = 0
  end
  env.steps = { table.unpack(steps, count + 1) }
end

---@param env StatisticsEnv
function processor.fini(env)
  env.connection:disconnect()
  env.unhandled_connection:disconnect()
  env.property_connection:disconnect()
  close(env)
end

local translator = {}

---@param env StatisticsEnv
function translator.init(env)
  open(env)
  env.prompt = env.engine.schema.config:get_string("lua/input") or "o"
end

---@param s table<string, integer>
---@param field string
---@param value integer
local function add(s, field, value)
  if field == "fastest" then
    s[field] = math.max(s[field] or 0, value)
  else
    s[field] = (s[field] or 0) + value
  end
end

--- 汇总本方案日期以 prefixes 中任一项开头的记录，返回「安装 → 统计」
---@param env StatisticsEnv
---@param prefixes string[]
local function collect(env, prefixes)
  ---@type table<string, table<string, integer>>
  local result = {}
  for _, prefix in ipairs(prefixes) do
    for key, value in env.db:query(env.schema_id .. " " .. prefix):iter() do
      local installation, field = key:match("^%S+ %d+ (.-) \t([%w_]+)$")
      if installation then
        result[installation] = result[installation] or {}
        add(result[installation], field, snow.parse(value) or 0)
      end
    end
  end
  return result
end

--- 取出 s 中 kind<i> 形式的字段，按 i 升序返回 { { i, 次数 }, ... }
---@param s table<string, integer>
---@param kind string
local function lengths(s, kind)
  ---@type integer[][]
  local result = {}
  for field, count in pairs(s) do
    local i = field:match("^" .. kind .. "(%d+)$")
    if i then
      table.insert(result, { tonumber(i), count })
    end
  end
  table.sort(result, function(a, b) return a[1] < b[1] end)
  return result
end

local digits = { "零", "一", "二", "三", "四", "五", "六", "七", "八", "九" }

--- 100 以内的数写成中文，如 10 → 十、12 → 十二、30 → 三十
---@param n integer
local function chinese(n)
  if n >= 100 then
    return tostring(n)
  end
  local tens, ones = math.floor(n / 10), n % 10
  local text = tens == 0 and "" or (tens == 1 and "十" or digits[tens + 1] .. "十")
  if ones > 0 or tens == 0 then
    text = text .. digits[ones + 1]
  end
  return text
end

--- 各档占上屏次数的比例，如「一字 40% 二字 35%」
---@param s table<string, integer>
---@param kind string
---@param unit string
local function distribution(s, kind, unit)
  local items = lengths(s, kind)
  local total = 0
  for _, item in ipairs(items) do
    total = total + item[2]
  end
  local parts = {}
  for _, item in ipairs(items) do
    table.insert(parts, ("%s%s %.0f%%"):format(chinese(item[1]), unit, item[2] * 100 / total))
  end
  return table.concat(parts, " ")
end

---@param segment Segment
---@param label string
---@param s table<string, integer>
local function report(segment, label, s)
  local chars, keys, effective_keys, duration = s.chars or 0, s.keys or 0, s.effective_keys or 0, s.duration or 0
  local text = ("%s %d 字"):format(label, chars)
  if chars > 0 and duration > 0 then
    text = text .. ("，均速 %.0f，极速 %d，击键 %.1f，码长 %.2f，键准 %.1f%%，理论码长 %.2f"):format(
      chars * 60000 / duration, s.fastest or 0, keys * 1000 / duration, keys / chars,
      effective_keys * 100 / keys, effective_keys / chars)
  end
  local comment = ("词长 %s；码长 %s"):format(distribution(s, "word", "字"), distribution(s, "code", "码"))
  yield(Candidate("statistics", segment.start, segment._end, text, chars > 0 and comment or ""))
end

--- 把全部方案、全部安装的数据按「方案、日期、安装」一行导出为 TSV，返回文件路径
---@param env StatisticsEnv
local function export(env)
  local path = rime_api.get_user_data_dir() .. "/" .. db_name .. ".tsv"
  local file = io.open(path, "w")
  if not file then
    return nil
  end
  file:write("schema\tdate\tinstallation\t" .. table.concat(columns, "\t") .. "\tword_distribution\tcode_distribution\n")
  -- LevelDB 按键排序，同一行的字段是连续的
  local group, row = nil, {}
  local function flush()
    if group then
      local values = {}
      for i, column in ipairs(columns) do
        values[i] = row[column] or 0
      end
      -- 分布写成「1:次数 2:次数」
      for _, kind in ipairs({ "word", "code" }) do
        local parts = {}
        for _, item in ipairs(lengths(row, kind)) do
          table.insert(parts, item[1] .. ":" .. item[2])
        end
        table.insert(values, table.concat(parts, " "))
      end
      file:write(group .. "\t" .. table.concat(values, "\t") .. "\n")
    end
  end
  for key, value in env.db:query(""):iter() do
    local schema, date, installation, field = key:match("^(%S+) (%d+) (.-) \t([%w_]+)$")
    if schema then
      local current = schema .. "\t" .. date .. "\t" .. installation
      if current ~= group then
        flush()
        group, row = current, {}
      end
      row[field] = snow.parse(value) or 0
    end
  end
  flush()
  file:close()
  return path
end

-- otj 本机，otjq 全部安装合并，otjs 各安装分列，otjd 导出
---@param input string
---@param segment Segment
---@param env StatisticsEnv
function translator.func(input, segment, env)
  local head = env.prompt .. "tj"
  if not env.db or input:sub(1, #head) ~= head then
    return
  end
  local command = input:sub(#head + 1)
  if command == "d" then
    local path = export(env)
    yield(Candidate("statistics", segment.start, segment._end, path or "导出失败", path and "已导出统计数据" or ""))
    return
  elseif command ~= "" and command ~= "q" and command ~= "s" then
    return
  end
  local now = os.date("*t")
  ---@cast now osdate
  local today = os.date("%Y%m%d")
  ---@cast today string
  ---@type string[]
  local week = {}
  for i = 0, (now.wday + 5) % 7 do
    table.insert(week, os.date("%Y%m%d", os.time({ year = now.year, month = now.month, day = now.day - i, hour = 12 })))
  end
  local labels = { "今日", "本周", "本月", "本年" }
  local data = { collect(env, { today }), collect(env, week), collect(env, { today:sub(1, 6) }), collect(env, { today:sub(1, 4) }) }
  if command == "s" then
    ---@type string[]
    local installations = {}
    for installation in pairs(data[4]) do
      table.insert(installations, installation)
    end
    table.sort(installations)
    for _, installation in ipairs(installations) do
      local name = installation == env.installation and installation .. "（本机）" or installation
      for i, label in ipairs(labels) do
        report(segment, name .. " " .. label, data[i][installation] or {})
      end
    end
    return
  end
  for i, label in ipairs(labels) do
    local s = data[i][env.installation] or {}
    if command == "q" then
      s = {}
      for _, t in pairs(data[i]) do
        for field, value in pairs(t) do
          add(s, field, value)
        end
      end
    end
    report(segment, label, s)
  end
end

---@param env StatisticsEnv
function translator.fini(env)
  close(env)
end

return {
  processor = processor,
  translator = translator,
}

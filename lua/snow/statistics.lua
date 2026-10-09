-- 输入统计处理器与翻译器
--
-- 用法（前缀为方案的 lua/input）：
--   tj   本机、本方案的今日、本周、本月、本年、累计统计，每个时段一个候选，分五行：
--        词数、字数、按键、有效按键、用时；均速、极速、击键、码长、键准、理论码长；平均词长、打词率；
--        词长分布；码长分布
--   rtj、ztj、ytj、ntj、qtj  只看今日、本周、本月、本年、累计中的一项
--   tjq  所有设备合并的统计（其他设备的数据经 Rime 同步后才会出现），也可以只看一项，如 rtjq
--   tjs  各设备分别列出，当前设备标「（本机）」，也可以只看一项，如 rtjs
-- 设备按 installation.yaml 的 installation_id 区分，可改成 macbook、phone 等易读的名字，
-- 但改名后旧数据仍记在旧名字下。
-- 数据存在用户目录下的 snow_statistics.userdb，Rime 同步时会和用户词典一样导出为 snow_statistics.userdb.txt。
--
-- 各量的含义：
--   词数      上屏的次数
--   字数      上屏的字符数，标点、数字、空格以及没有编码时直接输入的字符都算
--   按键      输入过程中按下的键数，组合键整组算一个，并击方案中一组并击算一个；临时西文和全局英文下的按键不算
--   有效按键  按键数减去两倍退格数，即退格和被它删掉的那个键都不算；没有打出任何编码的并击也不算
--   用时      相邻两次按键的间隔之和，超过 5 秒的间隔视为停顿，不计入
--   均速      字数 / 用时，单位为字/分
--   极速      每累计 60 秒用时结算一次分速，取最高值
--   击键      按键 / 用时，单位为键/秒
--   码长      按键 / 字数
--   键准      有效按键 / 按键
--   理论码长  有效按键 / 字数
--   平均词长  字数 / 词数
--   打词率    多字词上屏的字数 / 字数
--   词长分布  每次上屏的字数的分布，十字及以上合为一档
--   码长分布  每次上屏所用有效按键数的分布，即上次上屏后到这次上屏的按键，顶功时触发顶屏的键算给下一个词，
--             略码键算给重复出来的部分；
--             十码及以上合为一档
-- 详细口径和设计取舍见仓库 CLAUDE.md 的「输入统计」一节。

local snow = require "snow.snow"
local number = require "snow.number"

-- 两次击键间隔超过这个值（毫秒）视为停顿，不计入输入时长
local idle_ms = 5000
-- 每累计这么长的输入时长（毫秒）结算一次分速，取最高值作为极速
local window_ms = 60000
-- 所有方案、所有安装共用一个库，键为「方案 日期 安装 \t字段」，值为 `c=` 格式：这是用户词典快照
-- 的格式，同步时才能原样导出和合并。各安装只写带自己 installation_id 的键，且计数只增不减，
-- 所以合并时 UserDbMerger 取最大值就是该安装的最新值
-- 字段有 keys、duration（毫秒）、极速窗口的字数 window_chars 和时长 window_duration（毫秒），以及每次上屏
-- 各加一的 word<i>（这次上屏 i 个字）和
-- code<i>（距上次上屏有 i 个有效按键，编码中每按一次退格减一）。i 不设上限，所以字数 Σ i·word<i>、
-- 有效按键 Σ i·code<i> 和词数 Σ word<i> 都在显示时由这两组字段算出，不单独存
local db_name = "snow_statistics"

---@class StatisticsEnv: Env
---@field db LevelDb|nil
---@field schema_id string
---@field installation string
---@field prompt string
---@field connection Connection
---@field unhandled_connection Connection
---@field property_connection Connection
---@field last integer
---@field cancelling boolean
---@field steps { effective: integer, duration: integer }[]
---@field chord_keys table<integer, true>|nil
---@field held table<integer, true>
---@field chording boolean
---@field finishing boolean
---@field output integer
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

--- 一段输入的速度，单位为字/毫秒，时长为 0 时为 0
---@param chars integer|nil
---@param duration integer|nil
local function speed(chars, duration)
  return (duration or 0) > 0 and (chars or 0) / duration or 0
end

local processor = {}

---@param env StatisticsEnv
function processor.init(env)
  open(env)
  env.last = 0
  env.steps = {}
  env.cancelling = false
  env.window_chars = 0
  env.window_duration = 0
  -- 并击方案：按 chord_composer 的并击键跟踪并击，见 chord
  local alphabet = env.engine.schema.config:get_string("chord_composer/alphabet")
  if alphabet then
    env.chord_keys = {}
    for _, key_event in ipairs(KeySequence(alphabet):toKeyEvent()) do
      env.chord_keys[key_event.keycode] = true
    end
    env.held = {}
    env.chording = false
    env.finishing = false
    env.output = 0
  end
  local context = env.engine.context
  -- 选词、顶屏、回车上屏编码等经过 context:commit() 的上屏
  env.connection = context.commit_notifier:connect(function(ctx)
    -- 临时西文不属于中文输入：不记这次上屏，之前累计的按键（进入临时西文前打的中文编码）也不要了
    if ctx:get_option("ascii_mode") then
      env.steps = {}
      return
    end
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

--- 记一个按键
---@param env StatisticsEnv
---@param effective integer 计入有效按键的数目
local function step(env, effective)
  local now = rime_api.get_time_ms()
  table.insert(env.steps, {
    effective = effective,
    duration = now - env.last < idle_ms and now - env.last or 0,
  })
  env.last = now
end

--- 按 chord_composer 的规则跟踪并击，整组并击在最后一个键松开时算一个键。不是并击键时返回 nil，按普通按键处理
---@param key_event KeyEvent
---@param env StatisticsEnv
local function chord(key_event, env)
  local keycode = key_event.keycode
  -- 非并击键和带修饰键的键会让 chord_composer 放弃当前并击（冰雪一拼没有开 use_shift 等选项）
  if not env.chord_keys[keycode] or key_event:ctrl() or key_event:alt() or key_event:shift()
      or key_event:super() or key_event:caps() then
    env.held = {}
    env.chording = false
    return nil
  end
  if not key_event:release() then
    env.held[keycode] = true
    env.chording = true
    return snow.kNoop
  end
  if not env.held[keycode] then
    return snow.kNoop
  end
  env.held[keycode] = nil
  if next(env.held) or not env.chording then
    return snow.kNoop
  end
  env.chording = false
  -- 最后一个键松开时，chord_composer 把并击结果逐键合成、从链顶重投。这里先记下这组并击，再代为处理这个键，
  -- 把重投括起来跳过。并击要先记：重投中途就会上屏
  step(env, 1)
  env.finishing = true
  env.output = 0
  env.engine:process_key(key_event)
  env.finishing = false
  -- 没有打出任何编码的并击不算有效按键。没有合成按键也就不会上屏，这组并击还是最后一个
  if env.output == 0 then
    env.steps[#env.steps].effective = 0
  end
  return snow.kAccepted
end

---@param key_event KeyEvent
---@param env StatisticsEnv
function processor.func(key_event, env)
  -- popping 重投的按键已经记过一次
  if snow.redispatching then
    return snow.kNoop
  end
  -- 并击的合成按键不是用户按的，只数一下有几个
  if env.finishing then
    if not key_event:release() then
      env.output = env.output + 1
    end
    return snow.kNoop
  end
  local context = env.engine.context
  -- 上一个键是有编码时的 Escape 或临时西文下的键：如果它之后编码没了，就是放弃了这段输入，或者这段输入
  -- 作为西文上屏了，之前累计的按键都不要了。Escape 在缓冲区里只清最后一段，临时西文切回中文时编码可能还原，
  -- 所以要等它处理完（最晚到它自己的松开事件）再看
  if env.cancelling then
    env.cancelling = false
    if not context:is_composing() then
      env.steps = {}
    end
  end
  local composing = context:is_composing()
  -- 临时西文和全局英文都不属于中文输入，不记
  if context:get_option("ascii_mode") then
    env.cancelling = composing
    return snow.kNoop
  end
  if env.chord_keys then
    local result = chord(key_event, env)
    if result then
      return result
    end
  end
  local keycode = key_event.keycode
  -- 修饰键本身不记，和别的键一起按时整组算在那个键上
  if key_event:release() or keycode >= 0xffe1 and keycode <= 0xffee then
    return snow.kNoop
  end
  -- 没有编码时只记直接输入的可见字符，快捷键交给应用，不记
  if not composing and (key_event:ctrl() or key_event:alt() or key_event:super()
        or keycode < 0x20 or keycode > 0x7e) then
    return snow.kNoop
  end
  step(env, keycode == snow.kBackSpace and -1 or 1)
  env.cancelling = composing and keycode == snow.kEscape
  return snow.kNoop
end

--- 把上屏前累计的按键、有效按键和时长，连同这次上屏的字数、词长和码长写进当天的记录
---@param env StatisticsEnv
---@param text string 上屏的文字
---@param handover integer|nil 末尾有这么多有效按键属于下一个词（顶屏键和推回输入框的编码），不计入这次上屏
function processor.record(env, text, handover)
  local db = env.db
  local chars = utf8.len(text) or 0
  if not db or chars == 0 then
    return
  end
  local prefix = ("%s %s %s \t"):format(env.schema_id, os.date("%Y%m%d"), env.installation)
  local steps = env.steps
  -- 从末尾往回数到累计 handover 个有效按键为止，推回的编码中途回改过也能分对
  local count = #steps
  local rest = handover or 0
  while rest > 0 and count > 0 do
    rest = rest - steps[count].effective
    count = count - 1
  end
  env.steps = { table.unpack(steps, count + 1) }
  ---@type table<string, integer>
  local delta = { keys = count, duration = 0 }
  local effective = 0
  for i = 1, count do
    effective = effective + steps[i].effective
    delta.duration = delta.duration + steps[i].duration
  end
  -- 每次上屏至少有一个有效按键，不到一个说明按键归属出了偏差（如顶屏推回的编码含辅助码），整次丢掉
  if effective <= 0 then
    return
  end
  delta["word" .. chars] = 1
  delta["code" .. effective] = 1
  for field, value in pairs(delta) do
    db:update(prefix .. field, snow.format(fetch(db, prefix .. field) + value))
  end
  env.window_chars = env.window_chars + chars
  env.window_duration = env.window_duration + delta.duration
  if env.window_duration >= window_ms then
    -- 极速窗口的字数和时长分开存，同步合并时各取最大值，不一定出自同一个窗口，但窗口时长都在一分钟上下，偏差很小
    if speed(env.window_chars, env.window_duration)
        > speed(fetch(db, prefix .. "window_chars"), fetch(db, prefix .. "window_duration")) then
      db:update(prefix .. "window_chars", snow.format(env.window_chars))
      db:update(prefix .. "window_duration", snow.format(env.window_duration))
    end
    env.window_chars = 0
    env.window_duration = 0
  end
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

--- 把一条「方案 日期 安装」的记录并入统计：极速取速度更高的那个窗口，其余字段相加
---@param s table<string, integer>
---@param row table<string, integer>
local function merge(s, row)
  for field, value in pairs(row) do
    if field ~= "window_chars" and field ~= "window_duration" then
      s[field] = (s[field] or 0) + value
    end
  end
  if speed(row.window_chars, row.window_duration) > speed(s.window_chars, s.window_duration) then
    s.window_chars, s.window_duration = row.window_chars, row.window_duration
  end
end

--- 汇总本方案日期以 prefixes 中任一项开头的记录，返回「安装 → 统计」和所有安装合计的统计
---@param env StatisticsEnv
---@param prefixes string[]
local function collect(env, prefixes)
  -- 先按「方案 日期 安装」分组，极速窗口的两个字段要成对比较
  ---@type table<string, table<string, integer>>
  local rows = {}
  ---@type table<string, string>
  local installations = {}
  for _, prefix in ipairs(prefixes) do
    for key, value in env.db:query(env.schema_id .. " " .. prefix):iter() do
      local row, installation, field = key:match("^(%S+ %d+ (.-)) \t([%w_]+)$")
      if row then
        rows[row] = rows[row] or {}
        rows[row][field] = snow.parse(value) or 0
        installations[row] = installation
      end
    end
  end
  ---@type table<string, table<string, integer>>
  local result = {}
  ---@type table<string, integer>
  local total = {}
  for row, s in pairs(rows) do
    local installation = installations[row]
    result[installation] = result[installation] or {}
    merge(result[installation], s)
    merge(total, s)
  end
  return result, total
end

-- 词长、码长分布中这个长度及以上合为一档
local longest = 10

--- 由 word<i>、code<i> 算出词数、字数、有效按键，以及合并了长尾的词长、码长分布
---@param s table<string, integer>
local function summarize(s)
  local words, chars, effective_keys = 0, 0, 0
  ---@type table<string, table<integer, integer>>
  local buckets = { word = {}, code = {} }
  for field, count in pairs(s) do
    -- 词长、码长都至少为 1，word0、code0 是异常值，不匹配，丢掉
    local kind, digits = field:match("^(%a+)([1-9]%d*)$")
    local bucket = buckets[kind]
    if bucket then
      local i = tonumber(digits) --[[@as integer]]
      if kind == "word" then
        words = words + count
        chars = chars + i * count
      else
        effective_keys = effective_keys + i * count
      end
      local j = math.min(i, longest)
      bucket[j] = (bucket[j] or 0) + count
    end
  end
  return words, chars, effective_keys, buckets.word, buckets.code
end

--- 各档占上屏次数的比例，如「一字 40% 二字 35%」
---@param bucket table<integer, integer>
---@param total integer
---@param unit string
local function distribution(bucket, total, unit)
  local parts = {}
  for i = 1, longest do
    if bucket[i] then
      local name = number.chinese(i) .. unit .. (i == longest and "及以上" or "")
      table.insert(parts, ("%s %.0f%%"):format(name, bucket[i] * 100 / total))
    end
  end
  return table.concat(parts, " ")
end

---@param segment Segment
---@param label string
---@param s table<string, integer>
local function report(segment, label, s)
  local words, chars, effective_keys, word, code = summarize(s)
  local keys, duration = s.keys or 0, s.duration or 0
  local lines = {
    ("%s %d 词，%d 字，%d 键，%d 有效键，用时 %.0f 分"):format(label, words, chars, keys, effective_keys,
      duration / 60000),
  }
  if chars > 0 and duration > 0 then
    table.insert(lines, ("均速 %.2f，极速 %.2f，击键 %.2f，码长 %.2f，键准 %.2f%%，理论码长 %.2f"):format(
      chars * 60000 / duration, speed(s.window_chars, s.window_duration) * 60000, keys * 1000 / duration, keys / chars,
      effective_keys * 100 / keys, effective_keys / chars))
  end
  if chars > 0 then
    table.insert(lines, ("平均词长 %.2f，打词率 %.2f%%"):format(chars / words, (chars - (word[1] or 0)) * 100 / chars))
    table.insert(lines, "词长分布：" .. distribution(word, words, "字"))
    table.insert(lines, "码长分布：" .. distribution(code, words, "码"))
  end
  yield(Candidate("statistics", segment.start, segment._end, table.concat(lines, "\n"), ""))
end

-- tj 本机，tjq 全部安装合并，tjs 各安装分列；tj 前加 r、z、y、n、q 只看一个时段
---@param input string
---@param segment Segment
---@param env StatisticsEnv
function translator.func(input, segment, env)
  local prompt = env.prompt
  if not env.db or input:sub(1, #prompt) ~= prompt then
    return
  end
  local period, command = input:sub(#prompt + 1):match("^([rzynq]?)tj([qs]?)$")
  if not period then
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
  -- 命令字母、名称和日期前缀，空前缀匹配所有日期
  local periods = {
    { "r", "今日", { today } },
    { "z", "本周", week },
    { "y", "本月", { today:sub(1, 6) } },
    { "n", "本年", { today:sub(1, 4) } },
    { "q", "累计", { "" } },
  }
  ---@type string[]
  local labels = {}
  ---@type table<string, table<string, integer>>[]
  local data = {}
  ---@type table<string, integer>[]
  local totals = {}
  for _, p in ipairs(periods) do
    if period == "" or period == p[1] then
      table.insert(labels, p[2])
      data[#labels], totals[#labels] = collect(env, p[3])
    end
  end
  if command == "s" then
    -- 列出最后一个（也是最长的）时段里有数据的安装
    ---@type string[]
    local installations = {}
    for installation in pairs(data[#data]) do
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
    report(segment, label, command == "q" and totals[i] or data[i][env.installation] or {})
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

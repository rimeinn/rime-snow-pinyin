-- 输入统计处理器与翻译器
--
-- 用法（前缀为方案的 lua/input）：
--   tj   本机、本方案的今日、本周、本月、本年、累计统计，每个时段一个候选
--   rtj、ztj、ytj、ntj、qtj  只看今日、本周、本月、本年、累计中的一项
--   tjq  所有设备合并的统计（其他设备的数据经 Rime 同步后才会出现），也可以只看一项，如 rtjq
--   tjs  每个时段列出有数据的各设备，也可以只看一项，如 rtjs
-- 统计命令本身上屏时不记；方案的 statistics/exclude 可以再列出一些正则，上屏时整个输入（context.input）
-- 与其中任一个完全匹配就不记，例如 [ "o.*" ] 屏蔽所有 o 引导的输入。
-- 设备按 installation.yaml 的 installation_id 区分，可改成 macbook、phone 等易读的名字，
-- 但改名后旧数据仍记在旧名字下。用户目录下没有 installation.yaml 或其中没有 installation_id 时统计不工作。
-- 数据存在用户目录下的 snow_statistics.userdb，Rime 同步时会和用户词典一样导出为 snow_statistics.userdb.txt。
--
-- 各量的含义：
--   词数      上屏的次数
--   字数      上屏的字符数，标点、数字、空格以及没有编码时直接输入的字符都算，但没有编码时单独输入的空格、回车等空白符不算
--   按键      输入过程中按下的键数，组合键整组算一个，并击方案中一组并击算一个；临时西文和全局英文下的按键不算
--   有效按键  按键数减去两倍退格数，即退格和被它删掉的那个键都不算；没有打出任何编码的并击也不算
--   用时      相邻两次按键的间隔之和，超过 5 秒的间隔视为停顿，不计入
--   均速      字数 / 用时，单位为字/分
--   极速      每累计 60 秒用时结算一次分速，取最高值，不低于均速；用时不满 60 秒时不显示
--   击键      按键 / 用时，单位为键/秒
--   码长      按键 / 字数
--   键准      有效按键 / 按键
--   理论码长  有效按键 / 字数
--   平均词长  字数 / 词数
--   多字词占比  多字词上屏的字数 / 字数
--   词长分布  每次上屏的字数的分布，十字及以上合为一档
--   码长分布  每次上屏所用有效按键数的分布，即上次上屏后到这次上屏的按键，顶功时触发顶屏的键算给下一个词，
--             略码键算给重复出来的部分；
--             十码及以上合为一档
-- 详细口径和设计取舍见仓库 docs/statistics.md。

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
---@field installation string|nil
---@field prompt string
---@field exclude string[]
---@field schema_name string
---@field platform string
---@field connection Connection
---@field unhandled_connection Connection
---@field property_connection Connection
---@field expand_connection Connection
---@field reports table<string, string>
---@field last integer
---@field composing boolean
---@field committed boolean
---@field steps { effective: integer, duration: integer }[]
---@field chord_keys table<integer, true>|nil
---@field held table<integer, true>
---@field finishing boolean
---@field blank boolean
---@field output integer
---@field window_chars integer
---@field window_duration integer

---@param db LevelDb
---@param key string
local function fetch(db, key)
  return snow.parse(db:fetch(key) or "") or 0
end

-- 安装名直接读 installation.yaml，不用 rime_api.get_user_id()：后者是 deployer 的字段，只在本进程跑过
-- installation_update 时才会被赋值，只初始化、不维护的前端读到的是默认值 unknown，几台设备会挤在同一个名字下
---@param env StatisticsEnv
local function open(env)
  env.schema_id = env.engine.schema.schema_id
  env.prompt = env.engine.schema.config:get_string("lua/input") or "o"
  local config = Config()
  if config:load_from_file(rime_api.get_user_data_dir() .. "/installation.yaml") then
    env.installation = config:get_string("installation_id")
  end
  if env.installation and env.installation ~= "" then
    env.db = snow.get_db(db_name)
  end
end

---@param env StatisticsEnv
local function close(env)
  if env.db then
    env.db = nil
    snow.release_db(db_name)
  end
end

--- 两数之比，分母为 0 或缺失时为 0，报告里不会出现 inf 和 nan。也用来算速度（字/毫秒）
---@param numerator number|nil
---@param denominator number|nil
local function ratio(numerator, denominator)
  return (denominator or 0) > 0 and (numerator or 0) / denominator or 0
end

--- 统计命令（如 otj、rtjq）的时段字母和命令字母，不是统计命令时返回 nil
---@param input string
---@param prompt string
local function parse_command(input, prompt)
  if input:sub(1, #prompt) ~= prompt then
    return nil
  end
  return input:sub(#prompt + 1):match("^([rzynq]?)tj([qs]?)$")
end

--- 上屏时的输入是统计命令，或者与 statistics/exclude 中任一个正则完全匹配
---@param env StatisticsEnv
---@param input string
local function excluded(env, input)
  if parse_command(input, env.prompt) then
    return true
  end
  for _, pattern in ipairs(env.exclude) do
    if rime_api.regex_match(input, pattern) then
      return true
    end
  end
  return false
end

--- 从 env.steps 里取出属于这次上屏的按键
---@param env StatisticsEnv
---@param handover integer|nil 末尾有这么多有效按键属于下一个词（顶屏键和推回输入框的编码），留在 env.steps 里
local function take(env, handover)
  local steps = env.steps
  -- 从末尾往回数到累计 handover 个有效按键为止，推回的编码中途回改过也能分对
  local count = #steps
  local rest = handover or 0
  while rest > 0 and count > 0 do
    rest = rest - steps[count].effective
    count = count - 1
  end
  env.steps = { table.unpack(steps, count + 1) }
  return { table.unpack(steps, 1, count) }
end

--- 把上屏前累计的按键、有效按键和时长，连同这次上屏的字数、词长和码长写进当天的记录
---@param env StatisticsEnv
---@param text string 上屏的文字
---@param handover integer|nil 见 take
local function record(env, text, handover)
  local db = env.db
  local chars = utf8.len(text) or 0
  if not db or chars == 0 then
    return
  end
  local prefix = ("%s %s %s \t"):format(env.schema_id, os.date("%Y%m%d"), env.installation)
  local steps = take(env, handover)
  local count = #steps
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
    if ratio(env.window_chars, env.window_duration)
        > ratio(fetch(db, prefix .. "window_chars"), fetch(db, prefix .. "window_duration")) then
      db:update(prefix .. "window_chars", snow.format(env.window_chars))
      db:update(prefix .. "window_duration", snow.format(env.window_duration))
    end
    env.window_chars = 0
    env.window_duration = 0
  end
end

local processor = {}

---@param env StatisticsEnv
function processor.init(env)
  open(env)
  env.last = 0
  env.steps = {}
  env.composing = false
  env.committed = false
  env.window_chars = 0
  env.window_duration = 0
  env.exclude = {}
  local exclude = env.engine.schema.config:get_list("statistics/exclude")
  if exclude then
    for i = 1, exclude.size do
      local value = exclude:get_value_at(i - 1)
      if value then
        table.insert(env.exclude, value.value)
      end
    end
  end
  -- 并击方案：按 chord_composer 的并击键跟踪并击，见 chord
  local alphabet = env.engine.schema.config:get_string("chord_composer/alphabet")
  if alphabet then
    env.chord_keys = {}
    for _, key_event in ipairs(KeySequence(alphabet):toKeyEvent()) do
      env.chord_keys[key_event.keycode] = true
    end
    env.held = {}
    env.finishing = false
    env.blank = false
    env.output = 0
  end
  local context = env.engine.context
  -- 选词、顶屏、回车上屏编码等经过 context:commit() 的上屏
  env.connection = context.commit_notifier:connect(function(ctx)
    env.committed = true
    -- 临时西文不属于中文输入：不记这次上屏，之前累计的按键（进入临时西文前打的中文编码）也不要了
    if ctx:get_option("ascii_mode") then
      env.steps = {}
      return
    end
    if excluded(env, ctx.input) then
      take(env, snow.handover)
      return
    end
    record(env, ctx:get_commit_text(), snow.handover)
  end)
  -- 没有编码时直接放行给应用的可见字符（数字、标点等）记作一字词；popping 重投时放行的键并没有到达应用
  env.unhandled_connection = context.unhandled_key_notifier:connect(function(ctx, key_event)
    local keycode = key_event.keycode
    if snow.redispatching or ctx:get_option("ascii_mode") or key_event:release() or key_event:ctrl()
        or key_event:alt() or key_event:super() or keycode < 0x20 or keycode > 0x7e then
      return
    end
    -- 单独输入的空格不记；是并击打出来的话，那组并击也不记，见 chord
    if keycode == 0x20 then
      env.blank = env.finishing
      return
    end
    record(env, string.char(keycode))
  end)
  -- 以词定字、略码等用 snow.commit_text 直接上屏的
  env.property_connection = context.property_update_notifier:connect(function(ctx, name)
    if name == "commit_text" then
      env.committed = true
      record(env, ctx:get_property(name))
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
    return nil
  end
  if not key_event:release() then
    env.held[keycode] = true
    return snow.kNoop
  end
  if not env.held[keycode] then
    return snow.kNoop
  end
  env.held[keycode] = nil
  if next(env.held) then
    return snow.kNoop
  end
  -- 最后一个键松开时，chord_composer 把并击结果逐键合成、从链顶重投。这里先记下这组并击，再代为处理这个键，
  -- 把重投括起来跳过。并击要先记：重投中途就会上屏
  step(env, 1)
  local current = env.steps[#env.steps]
  env.finishing = true
  env.blank = false
  env.output = 0
  env.engine:process_key(key_event)
  env.finishing = false
  -- 没有编码时单独打出空格的并击整个不记。合成按键里如果先有别的上屏，这组并击已经结算过了，不再是最后一个
  if env.blank then
    if env.steps[#env.steps] == current then
      table.remove(env.steps)
    end
    -- 没有打出任何编码的并击不算有效按键。没有合成按键也就不会上屏，这组并击还是最后一个
  elseif env.output == 0 then
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
  -- 本处理器排在第一位，事件开始时的状态就是上一个事件处理完的状态。上一个事件开始时有编码，现在没了，
  -- 中间又没有上屏，就是这段输入被放弃了：Escape、退格删光、临时西文下作为西文上屏（不经过 commit_notifier）
  -- 等等。之前累计的按键都不要了
  local composing = context:is_composing()
  if env.composing and not composing and not env.committed then
    env.steps = {}
  end
  env.composing = composing
  env.committed = false
  -- 临时西文和全局英文都不属于中文输入，不记
  if context:get_option("ascii_mode") then
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
  -- 没有编码时只记直接输入的可见字符，快捷键交给应用，空格、回车等空白符单独输入也不算中文输入，都不记
  if not composing and (key_event:ctrl() or key_event:alt() or key_event:super()
        or keycode <= 0x20 or keycode > 0x7e) then
    return snow.kNoop
  end
  step(env, keycode == snow.kBackSpace and -1 or 1)
  return snow.kNoop
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
  env.schema_name = env.engine.schema.schema_name
  -- fcitx5-rime 的 distribution_name 只是 Rime，所以优先用 code_name
  local name = rime_api.get_distribution_code_name()
  if name == "" then
    name = rime_api.get_distribution_name()
  end
  env.platform = (name .. " " .. rime_api.get_distribution_version()):match("^%s*(.-)%s*$")
  if env.platform == "" then
    env.platform = "未知平台"
  end
  env.reports = {}
  -- 报告太长，候选只显示时段，上屏时再换成全文。分组的回调排在引擎自己的（未分组的）OnCommit
  -- 之前，引擎随后按选中候选的 text 取上屏文字，所以在这里改写 text 就能换掉上屏内容。改的是
  -- genuine：uniquifier 等包装器的 text 为空时取被包装的候选的
  env.expand_connection = env.engine.context.commit_notifier:connect(function(ctx)
    local cand = ctx:get_selected_candidate()
    if not cand then
      return
    end
    local genuine = cand:get_genuine()
    local full = env.reports[genuine.text]
    if full then
      genuine.text = full
    end
  end, 0)
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
  if ratio(row.window_chars, row.window_duration) > ratio(s.window_chars, s.window_duration) then
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

--- 各档占上屏次数的比例，如「一字 40%、二字 35%」；四舍五入为 0% 的档不显示
---@param bucket table<integer, integer>
---@param total integer
---@param unit string
local function distribution(bucket, total, unit)
  local parts = {}
  for i = 1, longest do
    local percent = ("%.0f"):format(ratio(bucket[i] or 0, total) * 100)
    if percent ~= "0" then
      local name = number.chinese(i) .. unit .. (i == longest and "及以上" or "")
      table.insert(parts, ("%s %s%%"):format(name, percent))
    end
  end
  return table.concat(parts, "、")
end

-- 报告中隔开开头、正文、分布和署名的分割线
local divider = ("─"):rep(14)

-- librime 自动生成的 installation_id，形如 8-4-4-4-12 位十六进制
local uuid = "^" .. ("%x"):rep(8) .. ("%-" .. ("%x"):rep(4)):rep(3) .. "%-" .. ("%x"):rep(12) .. "$"

--- 报告里显示的设备名。没改过的 UUID 只显示前 8 位，免得候选太长；这种名字认不出是哪台设备，
--- 所以本机再加「（本机）」，改过的名字不加
---@param env StatisticsEnv
---@param installation string
local function device(env, installation)
  if not installation:match(uuid) then
    return installation
  end
  return installation:sub(1, 8) .. (installation == env.installation and "（本机）" or "")
end

---@param env StatisticsEnv
---@param segment Segment
---@param title string 时段，如「2026 年 10 月 10 日」
---@param s table<string, integer>
---@param installation string|nil 统计所属的安装，nil 表示所有设备合并
---@param per_device boolean 是否为 tjs 类命令，是则显示设备行，并在候选里写设备名；所有设备合并时设备行显示「全部」
local function report(env, segment, title, s, installation, per_device)
  local words, chars, effective_keys, word, code = summarize(s)
  local keys, duration = s.keys or 0, s.duration or 0
  local lines = {
    "📊 " .. title .. "统计数据",
    ("⌨️ 方案：%s (%s)"):format(env.schema_name, env.schema_id),
  }
  -- 候选只显示 📊 加时段（第一行去掉「统计数据」），全文记下来，上屏时由 expand_connection 换上
  local brief = "📊 " .. title
  if not installation then
    table.insert(lines, "💻 设备：全部")
  elseif per_device then
    local name = device(env, installation)
    table.insert(lines, "💻 设备：" .. name)
    -- uniquifier 只按文字合并候选，tjs 里同一时段的各设备不能只靠注释区分
    brief = brief .. " · " .. name
  end
  -- 库里只记了安装，没记平台，所以只有本机的统计能显示平台
  if installation == env.installation then
    table.insert(lines, "🧩 平台：" .. env.platform)
  end
  table.insert(lines, divider)
  table.insert(lines, ("词 %d，字 %d，用时 %.0f 分"):format(words, chars, duration / 60000))
  table.insert(lines, ("键 %d，有效键 %d，键准 %.0f%%"):format(
    keys, effective_keys, ratio(effective_keys, keys) * 100))
  local average = ratio(chars, duration) * 60000
  local speed = ("均速 %.0f，"):format(average)
  -- 极速是至少一分钟的输入的最高平均速度。整个时段满一分钟时它本身就是一段，所以极速不低于均速；
  -- 会话末尾没满一分钟的窗口没有结算，不取最大值的话极速可能低于均速。不满一分钟时没有极速
  if duration >= window_ms then
    local fastest = math.max(ratio(s.window_chars, s.window_duration) * 60000, average)
    speed = speed .. ("极速 %.0f，"):format(fastest)
  end
  table.insert(lines, ("%s击键 %.2f"):format(speed, ratio(keys, duration) * 1000))
  if chars > 0 then
    table.insert(lines, ("码长 %.2f，理论码长 %.2f"):format(
      ratio(keys, chars), ratio(effective_keys, chars)))
    table.insert(lines, ("平均词长 %.2f，多字词占比 %.0f%%"):format(
      ratio(chars, words), ratio(chars - (word[1] or 0), chars) * 100))
    table.insert(lines, divider)
    table.insert(lines, "词长分布：" .. distribution(word, words, "字"))
    table.insert(lines, "码长分布：" .. distribution(code, words, "码"))
  end
  table.insert(lines, divider)
  table.insert(lines, "❄️ 冰雪统计 v" .. snow.version)
  table.insert(lines, "💬 冰雪拼音 QQ 群 1014366669")
  env.reports[brief] = table.concat(lines, "\n")
  yield(Candidate("statistics", segment.start, segment._end, brief, ""))
end

---@param t osdate
local function date(t)
  return ("%d 年 %d 月 %d 日"):format(t.year, t.month, t.day)
end

-- tj 本机，tjq 全部安装合并，tjs 各安装分列；tj 前加 r、z、y、n、q 只看一个时段
---@param input string
---@param segment Segment
---@param env StatisticsEnv
function translator.func(input, segment, env)
  local period, command = parse_command(input, env.prompt)
  if not env.db or not period then
    return
  end
  local now = os.date("*t")
  ---@cast now osdate
  local today = os.date("%Y%m%d")
  ---@cast today string
  --- i 天前的正午
  ---@param i integer
  local function ago(i)
    return os.time({ year = now.year, month = now.month, day = now.day - i, hour = 12 })
  end
  -- 本周从周一算起
  local offset = (now.wday + 5) % 7
  ---@type string[]
  local week = {}
  for i = 0, offset do
    table.insert(week, os.date("%Y%m%d", ago(i)))
  end
  -- ISO 8601 周：本周所在的年和周数都按本周的周四算，所以年初几天可能属于上一年的最后一周。
  -- 不用 os.date 的 %G、%V，因为 Windows 上的 Lua 只支持 C89 的格式符
  local thursday = os.date("*t", ago(offset - 3))
  ---@cast thursday osdate
  local week_title = ("%d 年 %d 周"):format(thursday.year, (thursday.yday - 1) // 7 + 1)
  -- 命令字母、日期范围和日期前缀，空前缀匹配所有日期
  local periods = {
    { "r", date(now), { today } },
    { "z", week_title, week },
    { "y", ("%d 年 %d 月"):format(now.year, now.month), { today:sub(1, 6) } },
    { "n", ("%d 年"):format(now.year), { today:sub(1, 4) } },
    { "q", "截至 " .. date(now) .. "累计", { "" } },
  }
  -- 选中的时段，每项为标题、「安装 → 统计」和合计
  ---@type { title: string, data: table<string, table<string, integer>>, total: table<string, integer> }[]
  local selected = {}
  for _, p in ipairs(periods) do
    if period == "" or period == p[1] then
      local data, total = collect(env, p[3])
      table.insert(selected, { title = p[2], data = data, total = total })
    end
  end
  env.reports = {}
  for _, t in ipairs(selected) do
    if command == "s" then
      -- 每个时段列出该时段里有数据的安装，本机在前，其余按名字排
      ---@type string[]
      local installations = {}
      for installation in pairs(t.data) do
        table.insert(installations, installation)
      end
      table.sort(installations, function(a, b)
        if (a == env.installation) ~= (b == env.installation) then
          return a == env.installation
        end
        return a < b
      end)
      for _, installation in ipairs(installations) do
        report(env, segment, t.title, t.data[installation], installation, true)
      end
    elseif command == "q" then
      report(env, segment, t.title, t.total, nil, false)
    else
      report(env, segment, t.title, t.data[env.installation] or {}, env.installation, false)
    end
  end
end

---@param env StatisticsEnv
function translator.fini(env)
  env.expand_connection:disconnect()
  close(env)
end

return {
  processor = processor,
  translator = translator,
}

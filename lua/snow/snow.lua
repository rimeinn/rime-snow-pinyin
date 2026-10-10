local snow = {
  kRejected = 0,
  kAccepted = 1,
  kNoop = 2,
  kVoid = "kVoid",
  kGuess = "kGuess",
  kSelected = "kSelected",
  kConfirmed = "kConfirmed",
  kNull = "kNull",     -- 空節點
  kScalar = "kScalar", -- 純數據節點
  kList = "kList",     -- 列表節點
  kMap = "kMap",       -- 字典節點
  kShift = 0x1,
  kLock = 0x2,
  kControl = 0x4,
  kAlt = 0x8,
  kSpace = 0x20,
  kBackSpace = 0xff08,
  kTab = 0xff09,
  kReturn = 0xff0d,
  kEscape = 0xff1b,
}

--- 取出输入中当前正在翻译的一部分
---@param context Context
function snow.current(context)
  local segment = context.composition:toSegmentation():back()
  if not segment then
    return nil
  end
  return context.input:sub(segment.start + 1, segment._end)
end

-- 冰雪拼音的版本号，是全仓库唯一的来源：用 `bun scripts/version.ts <版本号>` 修改，
-- 它会同时改写所有 snow_*.schema.yaml、snow_*.dict.yaml 里的 version
snow.version = "0.3.11"

snow.debug = false

-- popping 用 engine:process_key 重投按键期间为 true，排在它前面的处理器会再收到一次同一个键
snow.redispatching = false

-- 顶屏、略码上屏时为转给下一次上屏的有效按键数（触发顶屏的键加上推回输入框的编码，或略码键），供输入统计扣除
---@type integer|nil
snow.handover = nil

--- 绕过 context 直接上屏。这条路径不触发 commit_notifier，所以同时写一次 context 属性
--- `commit_text`，输入统计靠 property_update_notifier 补记
---@param engine Engine
---@param text string
---@param counted string|nil 输入统计记作的上屏文字，默认为 text；为空串时不记，留给之后的上屏一起记
function snow.commit_text(engine, text, counted)
  if text ~= "" then
    engine:commit_text(text)
  end
  counted = counted or text
  if counted ~= "" then
    engine.context:set_property("commit_text", counted)
  end
end

---格式化 Info 日志
---@param format string|number
function snow.infof(format, ...)
  if snow.debug then
    log.info(string.format(format, ...))
  end
end

---格式化 Warn 日志
---@param format string|number
function snow.warnf(format, ...)
  if snow.debug then
    log.warning(string.format(format, ...))
  end
end

---格式化 Error 日志
---@param format string|number
function snow.errorf(format, ...)
  if snow.debug then
    log.error(string.format(format, ...))
  end
end

---@param s string
---@param i number
---@param j number
function snow.sub(s, i, j)
  i = i or 1
  j = j or -1
  if i < 1 or j < 1 then
    local n = utf8.len(s)
    if not n then return "" end
    if i < 0 then i = n + 1 + i end
    if j < 0 then j = n + 1 + j end
    if i < 0 then i = 1 elseif i > n then i = n end
    if j < 0 then j = 1 elseif j > n then j = n end
  end
  if j < i then return "" end
  i = utf8.offset(s, i)
  j = utf8.offset(s, j + 1)
  if i and j then
    return s:sub(i, j - 1)
  elseif i then
    return s:sub(i)
  else
    return ""
  end
end

---@param s string
---@param sep string
function snow.split(s, sep)
  ---@type string[]
  local result = {}
  for part in s:gmatch("([^" .. sep .. "]+)") do
    table.insert(result, part)
  end
  return result
end

---@param env Env
function snow.get_dictionary_path(env)
  return rime_api.get_user_data_dir() .. ("/%s.fixed.txt"):format(env.engine.schema.schema_id)
end

---@param candidate Candidate
---@param proxy string
function snow.prepare(candidate, proxy, normal)
  local proxy_segment = proxy:sub(1, candidate._end - candidate._start)
  local real_segment = proxy_segment:gsub("[ ?~]", "")
  candidate._end = candidate._start + real_segment:len()
  -- 代理码里补出来的 ` `、`?`、`~` 也被 librime 算进了「全码匹配长度积分」
  -- （`quality_len / full_code_length`，见 script_translator.cc），于是带一个
  -- 分隔符的二字词代理码（`dl km`）会比不带分隔符的多字词简拼（`dlkm`）凭空高出
  -- 0.25，无论词频如何都稳压后者。这里把虚高减掉，让两路候选和键道直接查词
  -- 一样按词频排序。
  local real_input_length = proxy:gsub("[ ?~]", ""):len()
  local filler_length = proxy_segment:len() - real_segment:len()
  if filler_length > 0 and real_input_length > 0 then
    candidate.quality = candidate.quality - filler_length / real_input_length
  end
  if not normal then
    candidate.quality = candidate.quality + 1
  end
  -- candidate.comment = candidate.comment .. (" [%f, %d, %d]"):format(candidate.quality, candidate._start, candidate._end)
  return candidate
end

---@param candidate Candidate
---@param comment string
function snow.comment(candidate, comment)
  if candidate.comment ~= "" then
    candidate.comment = candidate.comment .. " " .. comment
  else
    candidate.comment = comment
  end
  return candidate
end

---@param path string
function snow.table_from_tsv(path)
  ---@type table<string, string>
  local result = {}
  local file = io.open(path, "r")
  if not file then
    return result
  end
  for line in file:lines() do
    ---@type string, string
    local character, content = line:match("([^\t]+)\t([^\t]+)")
    if not content or not character then
      goto continue
    end
    result[character] = content
    ::continue::
  end
  file:close()
  return result
end

---@param path string
function snow.read_dictionary(path)
  ---@type table<string, string[]>
  local result = {}
  local file = io.open(path, "r")
  if not file then
    return result
  end
  for line in file:lines() do
    ---@type string, string
    local code, content = line:match("([^\t]+)\t([^\t]+)")
    if not content or not code then
      goto continue
    end
    local words = {}
    for word in content:gmatch("[^%s]+") do
      table.insert(words, word)
    end
    result[code] = words
    ::continue::
  end
  file:close()
  return result
end

---@type string
snow.placeholder = "∅"
---@type table<string, LevelDb>
snow.db_pool = snow.db_pool or {}
---@type table<string, integer>
snow.ref_counter = snow.ref_counter or {}

-- 调用方必须在 init 时把 name 记在 env 里，fini 时用记下的 name 来 release。
-- 不能在 fini 里现取 env.engine.schema.schema_id：librime 的
-- ConcreteEngine::ApplySchema 先 schema_.reset(新方案)，再 InitializeComponents()
-- 清空旧组件触发 fini，此时 engine.schema 已经是新方案，拿它去 release 会放掉别人
-- 的计数，旧方案的词典则永远留在 db_pool 里独占 LOCK，同步时报
-- "IO error: lock ...: already held by process"。
---@param name string
---@return LevelDb|nil
function snow.get_db(name)
  local db = snow.db_pool[name]
  if not db then
    db = LevelDb(name)
    -- 用户词典是独占锁，被其他 rime 实例占着时打不开。此时返回 nil 退化成没有
    -- 用户词典，否则调用方会拿着未加载的 db 去 query，得到 nil 而报错
    if not db:loaded() and not db:open() then
      return nil
    end
    snow.db_pool[name] = db
    snow.ref_counter[name] = 1
  else
    snow.ref_counter[name] = snow.ref_counter[name] + 1
  end
  return db
end

---@param name string
function snow.release_db(name)
  local count = snow.ref_counter[name]
  if count == nil or count <= 0 then
    snow.errorf("用户词典 %s 的引用计数异常，没有被释放", tostring(name))
    return
  end
  count = count - 1
  if count <= 0 then
    local db = snow.db_pool[name]
    if db and db:loaded() then
      db:close()
    end
    snow.db_pool[name] = nil
    snow.ref_counter[name] = nil
    collectgarbage()
  else
    snow.ref_counter[name] = count
  end
end

-- 2025-11-01 00:00 GMT+0 对应的分钟数
snow.origin = 29365920
snow.separator = " \t"

snow.fixed_symbol = "📌"
snow.fixed_notfound_symbol = "📍"
snow.RADIX = 20
snow.DISABLE_INDEX = snow.RADIX - 1
snow.MAX_INDEX = snow.RADIX - 2

---@param epoch number
---@param index number
function snow.encode(epoch, index)
  return epoch * snow.RADIX + index
end

---@param value number
function snow.decode(value)
  local epoch = math.floor(value / snow.RADIX)
  local index = value % snow.RADIX
  return epoch, index
end

---@param code string
---@param word string
function snow.key(code, word)
  return code .. snow.separator .. word
end

---@param value number
function snow.format(value)
  return string.format("c=%d d=0 t=1", value)
end

function snow.epoch()
  return math.floor((os.time() / 60)) - snow.origin
end

---@param value string
function snow.parse(value)
  local num = tonumber(value:match("c=(%d+)"))
  if not num then
    return nil
  end
  return num
end

return snow

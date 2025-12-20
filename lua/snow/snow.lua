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

snow.debug = false

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

---@param env Env
function snow.get_dictionary_path(env)
  return rime_api.get_user_data_dir() .. ("/%s.fixed.txt"):format(env.engine.schema.schema_id)
end

---@param candidate Candidate
---@param proxy string
function snow.prepare(candidate, proxy, normal)
  candidate._end = candidate._start + proxy:gsub("[ ?~]", ""):len()
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

---@param name string
function snow.get_db(name)
  local db = snow.db_pool[name]
  if not db then
    db = LevelDb(name)
    if not db:loaded() then
      db:open()
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

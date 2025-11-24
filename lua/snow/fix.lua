-- 固定过滤器
-- 本过滤器读取用户自定义的固定短语，将其与当前翻译结果进行匹配，如果匹配成功，则将特定字词固定到特定位置

local snow = require "snow.snow"

local this = {}

---@class SnowFixedFilterEnv: Env
---@field fixed { string : string[] }

---@param env SnowFixedFilterEnv
function this.init(env)
  ---@type { string : string[] }
  env.fixed = {}
  local path = rime_api.get_user_data_dir() .. ("/%s.fixed.txt"):format(env.engine.schema.schema_id)
  local file = io.open(path, "r")
  if not file then
    return
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
    env.fixed[code] = words
    ::continue::
  end
  file:close()
end

---@param segment Segment
---@param env Env
function this.tags_match(segment, env)
  return segment:has_tag("abc")
end

---@param fixed_candidates Candidate[]
---@param free_candidates Candidate[]
function this.finalize(fixed_candidates, free_candidates)
  -- 输出固定的候选
  for _, fixed_candidate in ipairs(fixed_candidates) do
    yield(fixed_candidate)
  end
  -- 输出没有固定的候选
  for _, free_candidate in ipairs(free_candidates) do
    yield(free_candidate)
  end
end

---@param translation Translation
---@param env SnowFixedFilterEnv
function this.func(translation, env)
  local context = env.engine.context
  local segment = context.composition:toSegmentation():back()
  local input = snow.current(context)
  if not segment or not input then
    for candidate in translation:iter() do
      yield(candidate)
    end
    return
  end
  local shape_input = context:get_property("shape_input")
  if shape_input then
    input = input .. shape_input
  end
  local fixed_phrases = env.fixed[input]
  if not fixed_phrases then
    for candidate in translation:iter() do
      yield(candidate)
    end
    return
  end
  -- 生成固定候选
  ---@type Candidate[]
  local fixed_candidates = {}
  ---@type Candidate[]
  local free_candidates = {}
  for _, phrase in ipairs(fixed_phrases) do
    local dummy_candidate = Candidate("fixed", segment.start, segment._end, phrase, "")
    dummy_candidate.preedit = input
    table.insert(fixed_candidates, dummy_candidate)
  end
  -- 检查前 100 个候选，如果有与固定候选匹配的就替换，否则就添加到未知候选中
  local seen_candidates = 0
  local max_candidates = 100
  local finalized = false
  for candidate in translation:iter() do
    if finalized then
      yield(candidate)
      goto continue
    elseif seen_candidates == max_candidates or (candidate._end - candidate._start) < input:len() then
      this.finalize(fixed_candidates, free_candidates)
      finalized = true
      yield(candidate)
      goto continue
    end
    -- 对于一个新的候选，要么加入已知候选，要么加入未知候选
    local is_fixed = false
    for j = 1, #fixed_candidates do
      if candidate.text == fixed_candidates[j].text then
        fixed_candidates[j] = candidate
        is_fixed = true
        break
      end
    end
    if not is_fixed then
      table.insert(free_candidates, candidate)
    end
    seen_candidates = seen_candidates + 1
    ::continue::
  end
  if not finalized then
    this.finalize(fixed_candidates, free_candidates)
  end
end

return this

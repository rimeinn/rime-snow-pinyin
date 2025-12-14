-- 固定过滤器
-- 本过滤器读取用户自定义的固定短语，将其与当前翻译结果进行匹配，如果匹配成功，则将特定字词固定到特定位置

local snow = require "snow.snow"

local this = {}

---@class SnowFixedFilterEnv: Env
---@field dict table<string, string[]>
---@field user_dict LevelDb

---@param env SnowFixedFilterEnv
function this.init(env)
  local config = env.engine.schema.config
  env.dict = snow.read_dictionary(snow.get_dictionary_path(env))
  if config:get_bool("translator/enable_schema_user_dict") then
    env.user_dict = snow.get_db(env.engine.schema.schema_id)
  end
end

---@param segment Segment
---@param env Env
function this.tags_match(segment, env)
  return segment:has_tag("abc")
end

---@param fixed_candidates Candidate[]
---@param free_candidates Candidate[]
function this.finalize(fixed_candidates, free_candidates)
  ---@type integer
  local free_index = 1
  -- 输出固定的候选
  for j, fixed_candidate in ipairs(fixed_candidates) do
    if fixed_candidate.text == snow.placeholder and free_index <= #free_candidates then
      yield(free_candidates[free_index])
      free_index = free_index + 1
    else
      yield(fixed_candidate)
    end
  end
  -- 输出没有固定的候选
  for i = free_index, #free_candidates do
    yield(free_candidates[i])
  end
end

---@param env SnowFixedFilterEnv
---@param input string
function this.get_customized_list(env, input)
  ---@type string[]
  local fixed_phrases = {}
  if env.dict[input] then
    for _, phrase in ipairs(env.dict[input]) do
      table.insert(fixed_phrases, phrase)
    end
  end
  if not env.user_dict then
    return fixed_phrases
  end
  local max_index = 0
  local da = env.user_dict:query(input .. snow.separator)
  for k, v in da:iter() do
    local word = k:match("\t(.+)$")
    local value = snow.parse(v)
    if not value then
      goto continue
    end
    local _, index = snow.decode(value)
    if index == snow.DISABLE_INDEX then
      goto continue
    elseif index == 0 then
      for i = 1, #fixed_phrases do
        if fixed_phrases[i] == word then
          fixed_phrases[i] = snow.placeholder
          break
        end
      end
    end
    fixed_phrases[index] = word
    if index > max_index then
      max_index = index
    end
    ::continue::
  end
  ---@diagnostic disable-next-line: cast-local-type
  da = nil
  collectgarbage()
  for i = 1, max_index do
    if not fixed_phrases[i] then
      fixed_phrases[i] = snow.placeholder
    end
  end
  return fixed_phrases
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
  local full_input = input
  local shape_input = context:get_property("shape_input")
  if shape_input then
    full_input = input .. shape_input
  end
  local fixed_phrases = this.get_customized_list(env, full_input)
  if #fixed_phrases > 0 then
    snow.errorf("编码 %s：固定词 %s", full_input, table.concat(fixed_phrases, ", "))
  end
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
    local dummy_candidate = Candidate("fixed", segment.start, segment._end, phrase, snow.fixed_notfound_symbol)
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
        snow.comment(candidate, snow.fixed_symbol)
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

---@param env SnowFixedFilterEnv
function this.fini(env)
  env.dict = nil
  if env.user_dict then
    env.user_dict = nil
    snow.release_db(env.engine.schema.schema_id)
  end
end

return this

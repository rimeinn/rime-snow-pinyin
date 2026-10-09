-- 辅助码过滤器
-- 本过滤器根据上下文中的形码输入，过滤候选词，并在候选词上显示形码提示。

local snow = require "snow.snow"

---@class ShapeFilterEnv: Env
---@field strokes ReverseLookup
---@field shape_elements ReverseLookup
---@field shape_mapping table<string, string>

--- 将字符串中每一个字符替换为 map 中对应的值
---@param element string
---@param map table<string, string>
local function encode(element, map)
  local result = ""
  for _, c in utf8.codes(element) do
    local character = utf8.char(c)
    local value = map[character]
    if value then
      result = result .. value
    end
  end
  return result
end


local stroke_names = { ["h"] = "一", ["s"] = "丨", ["p"] = "丿", ["n"] = "丶", ["z"] = "乙" }
local sipin_stroke_map = { ["一"] = "e", ["丨"] = "i", ["丿"] = "u", ["丶"] = "o", ["乙"] = "a" }
local sanpin_stroke_map = { ["一"] = "v", ["丨"] = "i", ["丿"] = "u", ["丶"] = "o", ["乙"] = "a" }

--- 冰雪四拼和冰雪三拼的笔画匹配函数
--- @param text string
--- @param partial_code string
--- @param env ShapeFilterEnv
--- @param map table<string, string>
local function stroke_match(text, partial_code, env, map)
  ---@type table<string, string>
  local reverse_map = {}
  ---@type table<string, string>
  local direct_map = {}
  for k, v in pairs(map) do
    reverse_map[v] = k
  end
  for k, v in pairs(stroke_names) do
    direct_map[k] = map[v]
  end
  ---@type string?
  local prompt = nil
  if partial_code:len() > 0 then
    prompt = " 笔画 [" .. partial_code:gsub(".", reverse_map) .. "]"
  end
  -- 预览安装包不含笔画反查库，此时 env.strokes 为 nil，不做笔画过滤
  local elements = env.strokes and snow.split(env.strokes:lookup(text), " ") or {}
  local match = #elements == 0
  ---@type string[]
  local codes = {}
  for _, element in ipairs(elements) do
    local code = encode(element, direct_map)
    if code:len() > partial_code:len() + 4 then
      code = code:sub(1, partial_code:len() + 4) .. "~"
    end
    table.insert(codes, code)
    ---@type boolean
    match = match or code:sub(1, #partial_code) == partial_code
  end
  local comment = table.concat(codes, " ")
  return match, prompt, comment
end

--- @param text string
--- @param partial_code string
--- @param env ShapeFilterEnv
local function radical_match(text, partial_code, env)
  local element = env.shape_elements:lookup(text) or ""
  local code = encode(element, env.shape_mapping)
  local prompt = " 部首 [" .. partial_code .. "]"
  local comment = code .. " " .. element
  local match = not code or code:sub(1, #partial_code) == partial_code
  return match, prompt, comment
end

--- 键道的特殊处理
---@param text string
---@param current string
---@param radicals_map ReverseLookup
---@param map table<string, string>
local function jiandao_encode(text, current, radicals_map, map)
  -- 把 UTF-8 编码的词语拆成单个字符的列表
  ---@type string[]
  local codes = {}
  for _, codepoint in utf8.codes(text) do
    local char = utf8.char(codepoint)
    local radicals = radicals_map:lookup(char) or ""
    local code = ""
    for _, radical_codepoint in utf8.codes(radicals) do
      local r = utf8.char(radical_codepoint)
      local radical_code = map[r] or ""
      code = code .. radical_code
    end
    table.insert(codes, code)
  end
  local result = ""
  if #codes == 2 and current:len() == 1 then -- 630
    result = (codes[2] or "??"):sub(1, 2)
  elseif #codes == 1 then
    -- 如果只有一个字符，直接返回对应的编码
    result = codes[1] or "??"
  elseif #codes == 3 then
    -- 如果有三个字符，返回第一个字符的编码和第二个字符的编码
    result = (codes[1] or "?"):sub(1, 1) ..
        (codes[2] or "?"):sub(1, 1) .. (codes[3] or "?"):sub(1, 1)
  elseif #codes >= 2 then
    -- 如果有两个字符，返回第一个字符的编码和第二个字符的编码
    result = (codes[1] or "?"):sub(1, 1) .. (codes[2] or "?"):sub(1, 1)
  end
  return result
end

local filter = {}

---@param env ShapeFilterEnv
function filter.init(env)
  local config = env.engine.schema.config
  local dir = rime_api.get_user_data_dir() .. "/lua/snow/"
  env.strokes = ReverseLookup("stroke")
  local shape_elements = config:get_string("translator/shape_elements") or "snow_bushou"
  env.shape_elements = ReverseLookup(shape_elements)
  local shape_mapping = config:get_string("translator/shape_mapping") or "radical_sipin.txt"
  env.shape_mapping = snow.table_from_tsv(dir .. shape_mapping)
end

---@param text string
---@param shape_input string
---@param env ShapeFilterEnv
function filter.handle_candidate(text, shape_input, env)
  local segment = env.engine.context.composition:toSegmentation():back()
  local is_pinyin = segment and segment:has_tag("pinyin") or false
  local current = snow.current(env.engine.context) or ""
  local id = env.engine.schema.schema_id
  if id == "snow_sipin" then -- 冰雪四拼
    if shape_input:len() == 0 and not rime_api.regex_match(current, "[bpmfdtnlgkhjqxzcsrwyv][aeiou]{3}") then
      return true, nil, nil
    end
    if shape_input:sub(1, 1) == "1" then
      return radical_match(text, shape_input:sub(2), env)
    else
      return stroke_match(text, shape_input, env, sipin_stroke_map)
    end
  elseif id == "snow_sanpin" then -- 冰雪三拼
    if shape_input:len() == 0 and not rime_api.regex_match(current, "[bpmfdtnlgkhjqxzcsrywe][a-z][viuoa]") then
      return true, nil, nil
    end
    if shape_input:sub(1, 1) == "1" then
      return radical_match(text, shape_input:sub(2), env)
    else
      return stroke_match(text, shape_input, env, sanpin_stroke_map)
    end
  elseif id == "snow_jiandao" then -- 冰雪键道
    if is_pinyin or shape_input:len() > 0 or rime_api.regex_match(current, "[bpmfdtnlgkhjqxzcsrywe][a-z]([bpmfdtnlgkhjqxzcsrywe][a-z]?)?") then
      local code = jiandao_encode(text, current, env.shape_elements, env.shape_mapping)
      local prompt = shape_input:len() > 0 and " 形 [" .. shape_input .. "]" or nil
      local match = code == "" or code:sub(1, #shape_input) == shape_input
      local comment = code
      if not is_pinyin and current:len() == 1 then
        comment = "" -- 630 不需要提示
      elseif utf8.len(text) == 1 and (env.engine.context:get_option("chaifen") or is_pinyin) then
        local chaifen = env.shape_elements:lookup(text) or ""
        comment = comment .. " " .. chaifen
      end
      return match, prompt, comment
    else
      return true, nil, nil
    end
  elseif id == "snow_yipin" then -- 冰雪一拼
    local partial_code = ""
    local prompt = ""
    local element = env.shape_elements:lookup(text) or ""
    local code = encode(element, env.shape_mapping)
    local comment = (code .. " " .. element):gsub("rj", "'")
    if shape_input:sub(1, 1) == "v" then
      partial_code = shape_input:sub(2, -2):gsub("([a-z])%1", function(a, b)
        return a:upper()
      end)
      prompt = (" [" .. partial_code .. "]"):gsub("rj", "'")
    end
    local match = partial_code == "" or code == partial_code
    return match, prompt, comment
  else
    return true, nil, nil
  end
end

---@param translation Translation
---@param env ShapeFilterEnv
function filter.func(translation, env)
  local context = env.engine.context
  local shape_input = context:get_property("shape_input")
  local has_candidate = false
  local has_match = false
  ---@type string?
  local first_preedit = nil
  for candidate in translation:iter() do
    has_candidate = true
    local show, prompt, comment = filter.handle_candidate(candidate.text, shape_input, env)
    if not first_preedit and prompt then
      first_preedit = candidate.preedit .. prompt
    end
    if show then
      if comment then snow.comment(candidate, comment) end
      if prompt then candidate.preedit = candidate.preedit .. prompt end
      has_match = true
      yield(candidate)
    end
  end
  if has_candidate and not has_match then
    local segment = context.composition:toSegmentation():back()
    if not segment then
      return
    end
    local candidate = Candidate("hint", segment.start, segment._end, "🈚️", "无匹配候选词")
    candidate.preedit = first_preedit or ""
    yield(candidate)
  end
end

---@param segment Segment
---@param env Env
function filter.tags_match(segment, env)
  return segment:has_tag("abc") or segment:has_tag("pinyin")
end

---@param env ShapeFilterEnv
function filter.fini(env)
  env.strokes = nil
  env.shape_elements = nil
  env.shape_mapping = nil
  collectgarbage()
end

return filter

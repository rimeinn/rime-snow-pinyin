-- 辅助码过滤器
-- 本过滤器根据上下文中的形码输入，过滤候选词，并在候选词上显示形码提示。

local snow = require "snow.snow"

---@class AssistEnv: Env
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

---@param env AssistEnv
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
---@param env AssistEnv
function filter.handle_candidate(text, shape_input, env)
  local segment = env.engine.context.composition:toSegmentation():back()
  local is_pinyin = segment and segment:has_tag("pinyin") or false
  local current = snow.current(env.engine.context) or ""
  local id = env.engine.schema.schema_id
  if id == "snow_sipin" then -- 冰雪四拼
    if shape_input:len() > 0 or rime_api.regex_match(current, "[bpmfdtnlgkhjqxzcsrwyv][aeiou]{3}") then
      local code = ""
      local partial_code = ""
      ---@type string?
      local prompt = ""
      local comment = ""
      if shape_input:sub(1, 1) == "1" then
        partial_code = shape_input:sub(2)
        local element = env.shape_elements:lookup(text) or ""
        code = encode(element, env.shape_mapping)
        prompt = " 部首 [" .. partial_code .. "]"
        comment = code .. " " .. element
      else
        partial_code = shape_input
        local element = snow.split(env.strokes:lookup(text), " ")[1] or ""
        code = encode(element, { ["h"] = "e", ["s"] = "i", ["p"] = "u", ["n"] = "o", ["z"] = "a" })
        prompt = partial_code:len() > 0 and
            " 笔画 [" .. partial_code:gsub(".", { ["e"] = "一", ["i"] = "丨", ["u"] = "丿", ["o"] = "丶", ["a"] = "乙" }) .. "]" or
            nil
        comment = code
      end
      local match = not code or code:sub(1, #partial_code) == partial_code
      return match, prompt, comment
    else
      return true, nil, nil
    end
  elseif id == "snow_sanpin" then -- 冰雪三拼
    if shape_input:len() > 0 or rime_api.regex_match(current, "[bpmfdtnlgkhjqxzcsrywe][a-z][viuoa]") then
      local code = ""
      local partial_code = ""
      local prompt = ""
      local comment = ""
      if shape_input:sub(1, 1) == "1" then
        partial_code = shape_input:sub(2)
        local element = env.shape_elements:lookup(text) or ""
        code = encode(element, env.shape_mapping)
        prompt = " 部首 [" .. partial_code .. "]"
        comment = code .. " " .. element
      else
        partial_code = shape_input
        local element = snow.split(env.strokes:lookup(text), " ")[1] or ""
        code = encode(element, { ["h"] = "v", ["s"] = "i", ["p"] = "u", ["n"] = "o", ["z"] = "a" })
        prompt = " 笔画 [" ..
            partial_code:gsub(".", { ["v"] = "一", ["i"] = "丨", ["u"] = "丿", ["o"] = "丶", ["a"] = "乙" }) .. "]"
        comment = code
      end
      local match = not code or code:sub(1, #partial_code) == partial_code
      return match, prompt, comment
    else
      return true, nil, nil
    end
  elseif id == "snow_jiandao" then -- 冰雪键道
    if shape_input:len() > 0 or rime_api.regex_match(current, "[bpmfdtnlgkhjqxzcsrywe][a-z]([bpmfdtnlgkhjqxzcsrywe][a-z]?)?") then
      local code = jiandao_encode(text, current, env.shape_elements, env.shape_mapping)
      local prompt = shape_input:len() > 0 and " 形 [" .. shape_input .. "]" or nil
      local match = not code or code:sub(1, #shape_input) == shape_input
      local comment = code
      if current:len() == 1 then
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
---@param env AssistEnv
function filter.func(translation, env)
  local context = env.engine.context
  local shape_input = context:get_property("shape_input")
  for candidate in translation:iter() do
    local show, prompt, comment = filter.handle_candidate(candidate.text, shape_input, env)
    if show then
      if comment then snow.comment(candidate, comment) end
      if prompt then candidate.preedit = candidate.preedit .. prompt end
      yield(candidate)
    end
  end
end

---@param segment Segment
---@param env Env
function filter.tags_match(segment, env)
  return segment:has_tag("abc") or segment:has_tag("pinyin")
end

return filter

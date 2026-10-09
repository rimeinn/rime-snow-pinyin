-- 组词规则过滤器

local snow = require "snow.snow"

local filter = {}

---@param translation Translation
---@param env Env
function filter.func(translation, env)
  local input = snow.current(env.engine.context) or ""
  local shape_input = env.engine.context:get_property("shape_input")
  local full_input = input
  if shape_input then
    full_input = full_input .. shape_input
  end
  local jianpin = input:gsub("(.)", "%1 "):sub(1, -2)
  local shuangpin = input:gsub("(..)", "%1 "):sub(1, -2)
  -- 整句模式下，不允许简拼组词，其余都可以接受
  if not env.engine.context:get_option("popping") then
    for candidate in translation:iter() do
      local is_sentence = candidate:get_dynamic_type() == "Sentence"
      if is_sentence and candidate.preedit == jianpin then
        goto continue
      end
      yield(candidate)
      ::continue::
    end
    return
  end
  for candidate in translation:iter() do
    local is_phrase = candidate:get_dynamic_type() == "Phrase" or candidate:get_dynamic_type() == "Sentence"
    local is_normal_spelling = false
    local preedit = rime_api.regex_replace(candidate.preedit, " 形.+$", "")
    local is_character = utf8.len(candidate.text) == 1 and preedit:len() == 2
    if rime_api.regex_match(full_input, "[bpmfdtnlgkhjqxzcsrywe]{2}[vioua]*") then
      -- 两码时一定是双拼
      is_normal_spelling = preedit == shuangpin
    elseif rime_api.regex_match(full_input, "[bpmfdtnlgkhjqxzcsrywe]{4}[vioua]*") then
      -- 四码时可能是双拼，也可能是简拼
      is_normal_spelling = preedit == jianpin or preedit == shuangpin or is_character
    else
      -- 其他情况是简拼
      is_normal_spelling = preedit == jianpin
    end
    if not is_phrase or is_normal_spelling then
      yield(candidate)
    end
  end
end

---@param segment Segment
---@param env Env
function filter.tags_match(segment, env)
  return segment:has_tag("abc")
end

return filter

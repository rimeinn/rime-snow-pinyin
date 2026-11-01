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
  local jianpin = input:gsub("([bpmfdtnlgkhjqxzcsrywe][BPMFDTNLGKHJQXZCSRYWE]?)", "%1 "):sub(1, -2)
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
  local mixed_spelling = input:find("[BPMFDTNLGKHJQXZCSRYWE]") ~= nil
  local is_shuangpin = not mixed_spelling and rime_api.regex_match(full_input, "[bpmfdtnlgkhjqxzcsrywe]{2}[vioua]*")
  local is_four = not mixed_spelling and rime_api.regex_match(full_input, "[bpmfdtnlgkhjqxzcsrywe]{4}[vioua]*")
  for candidate in translation:iter() do
    -- 同段原生翻译结果按消耗长度降序排列。简拼只接受完整编码，遇到短候选即可结束，
    -- 不必逐个生成 preedit 再丢弃整批前缀词；四码仍保留单字，供选择造词使用。
    if not is_four and candidate._end - candidate._start < input:len() then
      return
    end
    local dynamic_type = candidate:get_dynamic_type()
    local is_phrase = dynamic_type == "Phrase" or dynamic_type == "Sentence"
    local is_normal_spelling = false
    local preedit = rime_api.regex_replace(candidate.preedit, " 形.+$", "")
    local is_character = utf8.len(candidate.text) == 1 and preedit:len() == 2
    if mixed_spelling then
      -- 大写韵母与前一个声母构成同一音节，仅用于三字及以上词
      is_normal_spelling = preedit == jianpin and utf8.len(candidate.text) >= 3
    elseif is_shuangpin then
      -- 两码时一定是双拼
      is_normal_spelling = preedit == shuangpin
    elseif is_four then
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

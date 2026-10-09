-- 特定码过滤器
-- 本过滤器在音节码以 s 开头的时候过滤掉包含「三」、「五」的候选，实现真正的数字无重化

local snow = require "snow.snow"

local filter = {}

---@param segment Segment
---@param env Env
function filter.tags_match(segment, env)
  return env.engine.schema.config:get_bool("speller/force_special")
end

---@param translation Translation
---@param env Env
function filter.func(translation, env)
  local context = env.engine.context
  -- 取出输入中当前正在翻译的一部分
  local input = snow.current(context)
  if not input then
    return
  end
  for candidate in translation:iter() do
    local index = 0
    for syllable in input:gmatch("[bpmfdtnlgkhjqxzcsrwyv][aeiou]*") do
      index = index + 1
      local char = snow.sub(candidate.text, index, index)
      if syllable:sub(1, 1) == "s" and (char == "三" or char == "五") then
        goto continue
      end
    end
    yield(candidate)
    ::continue::
  end
end

return filter

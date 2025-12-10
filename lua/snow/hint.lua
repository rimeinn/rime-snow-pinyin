local snow = require "snow.snow"
-- 提示过滤器
-- 目前仅用于提示键道的 630 简词

local filter = {}

---@class HintEnv: Env
---@field jiandao table<string, string>
---@field reverse_630 table<string, string>

---@param env HintEnv
function filter.init(env)
  env.jiandao = snow.table_from_tsv(rime_api.get_user_data_dir() .. "/snow_jiandao.fixed.txt")
  ---@type table<string, string>
  env.reverse_630 = {}
  for key, value in pairs(env.jiandao) do
    if rime_api.regex_match(key, "[bpmfdtnlgkhjqxzcsrywe][viuoa]{1,2}") then
      env.reverse_630[value] = key
    end
  end
end

---@param translation Translation
---@param env HintEnv
function filter.func(translation, env)
  local input = snow.current(env.engine.context) or ""
  local shape_input = env.engine.context:get_property("shape_input")
  if shape_input then
    input = input .. shape_input
  end
  local affix = { "v", "i", "u", "o", "a" }
  local first = true
  if rime_api.regex_match(input, "[bpmfdtnlgkhjqxzcsrywe][viuoa]?") then
    -- 一码，提示 sb 简词
    for candidate in translation:iter() do
      if first then
        yield(candidate)
        for _, letter in ipairs(affix) do
          local code = input .. letter
          local word = env.jiandao[code]
          if word then
            local hint_candidate = Candidate("hint", candidate.start, candidate._end, word, code)
            hint_candidate.preedit = input
            yield(hint_candidate)
          end
        end
      else
        yield(candidate)
      end
      first = false
    end
  elseif rime_api.regex_match(input, "[bpmfdtnlgkhjqxzcsrywe]{3,4}[vioua]*") then
    -- 四码，提示所有简词
    for candidate in translation:iter() do
      if env.reverse_630[candidate.text] then
        local code = env.reverse_630[candidate.text]
        snow.comment(candidate, ("[630: %s]"):format(code))
      end
      yield(candidate)
    end
  else
    -- 其他情况，直接返回
    for candidate in translation:iter() do
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

-- 冰雪英拼翻译器

local snow = require "snow.snow"

---@class YingpinEnv: Env
---@field translator Translator
---@field connection Connection

local translator = {}

---@param env YingpinEnv
function translator.init(env)
  env.translator = Component.Translator(env.engine, "translator", "table_translator")
  env.connection = env.engine.context.commit_notifier:connect(function(ctx)
    snow.commit_text(env.engine, " ")
  end)
end

---@type table<string, string>
local initial_lookup = {
  ["a"] = "j",
  ["e"] = "q",
  ["o"] = "x",
  ["i"] = "k",
  ["u"] = "z",
}

---@param input string
---@param segment Segment
---@param env YingpinEnv
function translator.func(input, segment, env)
  local consonants = input:gsub("[aeiou]", "")
  local lookup_consonants = consonants
  if lookup_consonants:len() > 4 then
    lookup_consonants = lookup_consonants:sub(1, 4)
  end
  local vowels = input:gsub("[^aeiou]", "")
  -- 一字词
  local translation = env.translator:query(lookup_consonants, segment)
  if not translation then
    return
  end
  for candidate in translation:iter() do
    local text = candidate.text
    -- 如果以元音开头，尝试添加零声母
    local zero_initial = initial_lookup[text:sub(1, 1)]
    if zero_initial then
      text = zero_initial .. text
    end
    -- 去掉元音后比较声母
    local text_consonants = text:gsub("[aeiou]", "")
    if text_consonants:sub(1, #consonants) ~= consonants then
      goto continue
    end
    -- 比较韵母，短的韵母可以通过重复最后一个元音来匹配长的韵母
    ---@type string
    local text_vowels = text:gsub("[^aeiou]", "")
    if text_vowels:len() < vowels:len() then
      local last_text_vowel = text_vowels:sub(-1)
      text_vowels = text_vowels .. last_text_vowel:rep(vowels:len() - text_vowels:len())
    end
    if text_vowels:sub(1, #vowels) == vowels then
      candidate.preedit = input
      candidate._end = segment._end
      yield(candidate)
    end
    ::continue::
  end
end

---@param env YingpinEnv
function translator.fini(env)
  env.translator = nil
  env.connection:disconnect()
  collectgarbage()
end

return translator

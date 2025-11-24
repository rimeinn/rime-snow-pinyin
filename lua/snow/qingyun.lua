-- 清韵方案过滤器

local snow = require("snow.snow")

local filter = {}

---@class QingyunEnv: Env
---@field fixed table<string, string>
---@field reverse_lookup table<string, string[]>
---@field lookup_pinyin ReverseLookup
---@field memory Memory

---@param env QingyunEnv
function filter.init(env)
  env.fixed = snow.table_from_tsv(rime_api.get_user_data_dir() .. "/snow_qingyun.fixed.txt")
  env.reverse_lookup = {}
  for code, content in pairs(env.fixed) do
    for word in content:gmatch("[^%s]+") do
      if not env.reverse_lookup[word] then
        env.reverse_lookup[word] = {}
      end
      table.insert(env.reverse_lookup[word], code)
      table.sort(env.reverse_lookup[word])
    end
  end
  env.lookup_pinyin = ReverseLookup("snow_pinyin")
  env.memory = Memory(env.engine, env.engine.schema, "pinyin")
end

---@param candiate Candidate
function is_pinyin(candiate)
  return candiate.preedit:sub(1, 1) == "["
end

---@param translation Translation
---@param env QingyunEnv
function filter.func(translation, env)
  local count = 0
  local input = snow.current(env.engine.context) or "";
  local segment = env.engine.context.composition:toSegmentation():back()
  local affix = { "a", "o", "e", "i", "u", ";", ",", ".", "/" }
  for candidate in translation:iter() do
    -- 生成一简十重提示
    if input:len() == 1 then
      if count == 0 then
        local hint = ""
        for _, letter in ipairs(affix) do
          local code = candidate.preedit .. letter
          local word = env.fixed[code]
          if word then
            -- local fixed_candidate = Candidate("qingyun", candidate.start, candidate._end, word, letter)
            -- fixed_candidate.preedit = candidate.preedit
            -- yield(fixed_candidate)
            hint = hint .. word:match("^[^%s]+") .. letter .. " "
          end
        end
        candidate.comment = hint
        yield(candidate)
      end
      count = count + 1
    elseif env.engine.context:get_option("buffered") and not is_pinyin(candidate) then
      local result = env.lookup_pinyin:lookup(candidate.text)
      candidate.comment = result
      ---@type Candidate[]
      local candidates = {}
      for pinyin in result:gmatch("[^%s]+") do
        env.memory:dict_lookup(pinyin, true, 100)
        for entry in env.memory:iter_dict() do
          if entry.text == candidate.text then
            local phrase = Phrase(env.memory, "phrase", candidate.start, candidate._end, entry)
            local c = phrase:toCandidate()
            c.comment = pinyin
            table.insert(candidates, c)
          end
        end
      end
      table.sort(candidates, function(a, b) return a.quality < b.quality end)
      for _, c in ipairs(candidates) do
        yield(c)
      end
    elseif utf8.len(candidate.text) == 1 and (is_pinyin(candidate) or (segment and (segment:has_tag("pinyin") or segment:has_tag("stroke")))) then
      -- 生成多音字提示
      local codes = env.reverse_lookup[candidate.text]
      if codes then
        candidate.comment = table.concat(codes, " ")
      end
      if candidate.preedit:sub(1, 1) == "[" then
        candidate.preedit = candidate.preedit:sub(2, -2)
      end
      yield(candidate)
    elseif candidate.type == "sentence" and (not is_pinyin(candidate)) then
      -- 过滤掉冰雪清韵形码的组句候选
    else
      if candidate.preedit:sub(1, 1) == "[" then
        candidate.preedit = candidate.preedit:sub(2, -2)
      end
      -- 补齐空格以便阅读
      candidate.preedit = rime_api.regex_replace(candidate.preedit,
        "(?<=[bpmfdtnlgkhjqxzcsrwyv])(?=[bpmfdtnlgkhjqxzcsrwyv])", " ")
      yield(candidate)
    end
  end
end

---@param env QingyunEnv
function filter.fini(env)
  env.fixed = nil
  env.reverse_lookup = nil
  env.lookup_pinyin = nil
  collectgarbage()
end

return filter

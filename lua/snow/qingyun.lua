-- 清韵方案过滤器

local snow = require("snow.snow")

local filter = {}

---@class QingyunEnv: Env
---@field fixed table<string, string>
---@field reverse_lookup table<string, string[]>
---@field lookup_pinyin ReverseLookup
---@field memory Memory
---@field chaifen table<string, string>
---@field connection Connection

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
  env.chaifen = snow.table_from_tsv(rime_api.get_user_data_dir() .. "/lua/snow/qingyun_chaifen.txt")
  env.connection = env.engine.context.commit_notifier:connect(function(ctx)
    local reset = env.engine.schema.config:get_int("switches/7/reset")
    snow.errorf("清韵方案：重置选项，chaifen=%s", tostring(reset))
    local target = reset == 1 and true or false
    local current = ctx:get_option("character")
    if current ~= target then
      ctx:set_option("character", target)
    end
  end)
end

---@param candiate Candidate
function is_pinyin(candiate)
  return candiate.preedit:sub(1, 1) == "["
end

---@param candidate Candidate
function prettify_preedit(candidate)
  if candidate.preedit:sub(1, 1) == "[" then
    candidate.preedit = candidate.preedit:sub(2, -2)
  end
  -- 补齐空格以便阅读
  candidate.preedit = rime_api.regex_replace(candidate.preedit,
    "(?<=[bpmfdtnlgkhjqxzcsrwyv])(?=[bpmfdtnlgkhjqxzcsrwyv])", " ")
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
    if rime_api.regex_match(input, "[bpmfdtnlgkhjqxzcsrvwy]{1,2}") then
      if count == 0 then
        local hint = ""
        for _, letter in ipairs(affix) do
          local code = input .. letter
          local word_list = env.fixed[code]
          if word_list then
            local word = word_list:match("^[^%s]+")
            if input:len() == 1 or utf8.len(word) > 1 then
              ---@type string
              hint = hint .. word .. letter .. " "
            end
          end
        end
        candidate.comment = candidate.comment .. hint
        prettify_preedit(candidate)
        yield(candidate)
      end
      count = count + 1
    elseif env.engine.context:get_option("buffered") and not is_pinyin(candidate) then
      local result = env.lookup_pinyin:lookup(candidate.text)
      candidate.comment = candidate.comment .. result
      ---@type Candidate[]
      local candidates = {}
      for pinyin in result:gmatch("[^%s]+") do
        env.memory:dict_lookup(pinyin, true, 100)
        for entry in env.memory:iter_dict() do
          if entry.text == candidate.text then
            local phrase = Phrase(env.memory, "phrase", candidate.start, candidate._end, entry)
            local c = phrase:toCandidate()
            c.comment = pinyin
            c.quality = entry.weight
            table.insert(candidates, c)
          end
        end
      end
      table.sort(candidates, function(a, b) return a.quality > b.quality end)
      for _, c in ipairs(candidates) do
        yield(c)
      end
    elseif utf8.len(candidate.text) == 1 and (is_pinyin(candidate) or (segment and (segment:has_tag("pinyin") or segment:has_tag("stroke")))) then
      -- 生成多音字提示
      local codes = env.reverse_lookup[candidate.text]
      if codes then
        candidate.comment = table.concat(codes, " ")
        if env.engine.context:get_option("chaifen") then
          local chaifen = env.chaifen[candidate.text]
          if chaifen then
            candidate.comment = candidate.comment .. "［" .. chaifen .. "］"
          end
        end
      end
      prettify_preedit(candidate)
      yield(candidate)
    elseif candidate.type == "sentence" and (not is_pinyin(candidate)) then
      -- 过滤掉冰雪清韵形码的组句候选
    else
      prettify_preedit(candidate)
      local character_only = env.engine.context:get_option("character")
      if character_only and utf8.len(candidate.text) > 1 then
        goto continue
      end
      yield(candidate)
      ::continue::
    end
  end
end

---@param env QingyunEnv
function filter.fini(env)
  env.fixed = nil
  env.reverse_lookup = nil
  env.lookup_pinyin = nil
  env.memory = nil
  collectgarbage()
end

return filter

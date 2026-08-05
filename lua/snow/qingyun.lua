-- 冰雪清韵方案过滤器

local snow = require("snow.snow")

local this = {}

---@class QingyunEnv: Env
---@field fixed table<string, string>
---@field reverse_lookup table<string, string[]>
---@field lookup_pinyin ReverseLookup
---@field memory Memory
---@field chaifen ReverseLookup
---@field connection Connection

---@param env QingyunEnv
function this.init(env)
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
  env.chaifen = ReverseLookup("snow_qingyun_chaifen")
  env.connection = env.engine.context.commit_notifier:connect(function(ctx)
    local reset = env.engine.schema.config:get_int("switches/3/reset")
    local target = reset == 1 and true or false
    local current = ctx:get_option("character")
    if current ~= target then
      ctx:set_option("character", target)
      snow.errorf("自动%s单字模式", target and "启用" or "关闭")
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
function this.func(translation, env)
  local count = 0
  local input = snow.current(env.engine.context) or "";
  local segment = env.engine.context.composition:toSegmentation():back()
  local affix = { "a", "o", "e", "i", "u", ";", ",", ".", "/" }
  for candidate in translation:iter() do
    if env.engine.context:get_option("buffered") and not is_pinyin(candidate) then
      local result = env.lookup_pinyin:lookup(candidate.text)
      snow.comment(candidate, result)
      ---@type Candidate[]
      local candidates = {}
      for pinyin in result:gmatch("[^%s]+") do
        env.memory:dict_lookup(pinyin, true, 100)
        for entry in env.memory:iter_dict() do
          if entry.text == candidate.text then
            local phrase = Phrase(env.memory, "phrase", candidate.start, candidate._end, entry)
            local c = phrase:toCandidate()
            c.comment = candidate.comment
            snow.comment(c, pinyin)
            c.quality = entry.weight
            table.insert(candidates, c)
          end
        end
      end
      table.sort(candidates, function(a, b) return a.quality > b.quality end)
      for _, c in ipairs(candidates) do
        yield(c)
      end
      goto continue
    end
    if candidate.type == "sentence" and (not is_pinyin(candidate)) then
      goto continue -- 过滤掉冰雪清韵形码的组句候选
    end
    local character_only = env.engine.context:get_option("character")
    if character_only and utf8.len(candidate.text) > 1 then
      goto continue
    end
    if rime_api.regex_match(input, "[bpmfdtnlgkhjqxzcsrvwy]{1,2}") then -- 生成一简十重提示
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
        if utf8.len(candidate.text) > 1 then -- 第一个候选就是词
          local c = Candidate("placeholder", candidate.start, candidate._end, "🈚️", hint)
          c.preedit = candidate.preedit
          count = count + 1
          prettify_preedit(c)
          yield(c)
          goto continue
        else
          snow.comment(candidate, hint)
        end
      else
        goto continue
      end
      count = count + 1
    elseif utf8.len(candidate.text) == 1 and (is_pinyin(candidate) or (segment and (segment:has_tag("pinyin") or segment:has_tag("stroke")))) then -- 生成反查提示
      local codes = env.reverse_lookup[candidate.text]
      if codes then
        snow.comment(candidate, table.concat(codes, " "))
      end
    else
      local codes = env.reverse_lookup[candidate.text]
      if codes then
        local shorter_codes = {}
        for _, code in ipairs(codes) do
          if code:len() < input:len() then
            table.insert(shorter_codes, code)
          end
        end
        if #shorter_codes > 0 then
          snow.comment(candidate, table.concat(shorter_codes, " "))
        end
      end
    end
    if env.engine.context:get_option("chaifen") then
      local chaifen = env.chaifen:lookup(candidate.text)
      if chaifen:len() > 0 then
        snow.comment(candidate, "~ " .. chaifen:gsub("-", " "))
      end
    end
    prettify_preedit(candidate)
    yield(candidate)
    ::continue::
  end
end

---@param env QingyunEnv
function this.fini(env)
  env.fixed = nil
  env.reverse_lookup = nil
  env.lookup_pinyin = nil
  env.memory = nil
  env.chaifen = nil
  env.connection:disconnect()
  collectgarbage()
end

return this

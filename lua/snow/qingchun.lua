-- 冰雪清纯方案过滤器

local snow = require("snow.snow")

local this = {}

---@class QingchunEnv: Env
---@field memory Memory
---@field chaifen table<string, string>

---@param env QingchunEnv
function this.init(env)
  env.memory = Memory(env.engine, env.engine.schema)
  env.chaifen = snow.table_from_tsv(rime_api.get_user_data_dir() .. "/lua/snow/qingyun_chaifen.txt")
end

---@param translation Translation
---@param env QingchunEnv
function this.func(translation, env)
  local count = 0
  local input = snow.current(env.engine.context) or "";
  local segment = env.engine.context.composition:toSegmentation():back()
  if not segment then
    for candidate in translation:iter() do
      yield(candidate)
    end
    return
  end
  local affix = { "a", "o", "e", "i", "u", ";", ",", ".", "/" }
  local c = Candidate("placeholder", segment.start, segment._end, "🈚️", "")
  c.preedit = input
  -- 分情况讨论
  if segment:has_tag("pinyin") or segment:has_tag("stroke") then -- 生成反查提示
    for candidate in translation:iter() do
      if env.engine.context:get_option("chaifen") then
        local chaifen = env.chaifen[candidate.text]
        if chaifen then
          snow.comment(candidate, "~ " .. chaifen)
        end
      end
      yield(candidate)
    end
  else
    if rime_api.regex_match(input, "[bpmfdtnlgkhjqxzcsrvwy]{1,2}") then -- 生成一简十重提示
      ---@type string[]
      local hints = {}
      for _, letter in ipairs(affix) do
        local code = input .. letter
        env.memory:dict_lookup(code, false, 0)
        for entry in env.memory:iter_dict() do
          if input:len() == 1 or utf8.len(entry.text) > 1 then
            table.insert(hints, entry.text .. code)
          end
        end
      end
      local hint = table.concat(hints, " ")
      for candidate in translation:iter() do
        if count == 0 then
          candidate.comment = hint
          yield(candidate)
        end
        count = count + 1
      end
      if count == 0 then -- 没有候选时也显示提示
        snow.comment(c, hint)
        yield(c)
      else
      end
    else
      -- 生成简码提示
      for candidate in translation:iter() do
        local comment = candidate.comment or ""
        local shorter_codes = {}
        for code in comment:gmatch("[^%s]+") do
          if code:len() < input:len() then
            table.insert(shorter_codes, code)
          end
        end
        candidate.comment = table.concat(shorter_codes, " ")
        yield(candidate)
      end
    end
  end
end

---@param env QingchunEnv
function this.fini(env)
  env.memory = nil
  env.chaifen = nil
  collectgarbage()
end

return this

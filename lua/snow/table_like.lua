-- 模拟码表翻译器
-- 适用于：冰雪三拼、冰雪键道

local snow = require "snow.snow"

---@class ProxyTranslatorEnv: Env
---@field translator Translator
---@field pattern string
---@field pattern2 string
---@field pattern3 string

local t12 = {}

---@param env ProxyTranslatorEnv
function t12.init(env)
  env.translator = Component.Translator(env.engine, "translator", "script_translator")
  env.pattern = env.engine.schema.config:get_string("translator/t1_pattern") or "^.+$"
  env.pattern2 = env.engine.schema.config:get_string("translator/t2_pattern") or "^.+$"
  env.pattern3 = env.engine.schema.config:get_string("translator/t3_pattern") or "^.+$"
end

---@param input string
---@param segment Segment
---@param env ProxyTranslatorEnv
function t12.func(input, segment, env)
  -- 一字词
  if rime_api.regex_match(input, env.pattern) or env.engine.context:get_option("fluid") == true then
    local translation = env.translator:query(input, segment)
    for candidate in translation:iter() do
      yield(snow.prepare(candidate, input, true))
    end
    if input:len() == 2 then
      local proxy = ("%s %s"):format(input:sub(1, 1), input:sub(2))
      local translation2 = env.translator:query(proxy, segment)
      for candidate in translation2:iter() do
        yield(snow.prepare(candidate, proxy, true))
      end
    end
  end
  local is_sanding = env.engine.context:get_option("popping1")
  local pattern = is_sanding and env.pattern3 or env.pattern2
  -- 二字词
  if rime_api.regex_match(input, pattern) then
    local proxy = ("%s %s"):format(input:sub(1, 2), input:sub(3))
    if input:len() == 6 then
      proxy = ("%s%s %s"):format(input:sub(1, 2), input:sub(-1, -1), input:sub(3, -2))
    end
    local translation = env.translator:query(proxy, segment)
    for candidate in translation:iter() do
      if utf8.len(candidate.text) <= 2 then
        yield(snow.prepare(candidate, proxy, not is_sanding))
      end
    end
  end
end

---@param env ProxyTranslatorEnv
function t12.fini(env)
  env.translator = nil
  collectgarbage()
end

local jianpin = {}

---@param env ProxyTranslatorEnv
function jianpin.init(env)
  env.translator = Component.Translator(env.engine, "jianpin", "script_translator")
  env.pattern = env.engine.schema.config:get_string("translator/jianpin_pattern") or "^.+$"
end

---@param input string
---@param segment Segment
---@param env ProxyTranslatorEnv
function jianpin.func(input, segment, env)
  -- 多字词
  if rime_api.regex_match(input, env.pattern) then
    local proxy = input:gsub("[viuoa]", "")
    local buma = input:gsub("[bpmfdtnlgkhjqxzcsrywe]", "");
    if buma:len() == 1 then
      proxy = ("%s?%s"):format(proxy, buma)
    elseif buma:len() == 2 then
      proxy = ("%s?%s%s?%s"):format(
        proxy:sub(1, 1),
        buma:sub(2),
        proxy:sub(2),
        buma:sub(1, 1)
      )
    elseif buma:len() == 3 then
      proxy = ("%s?%s%s?%s%s?%s"):format(
        proxy:sub(1, 1),
        buma:sub(2, 2),
        proxy:sub(2, 2),
        buma:sub(3, 3),
        proxy:sub(3),
        buma:sub(1, 1)
      )
    end
    local translation = env.translator:query(proxy, segment)
    for candidate in translation:iter() do
      if utf8.len(candidate.text) >= input:gsub("[viuoa]", ""):len() and candidate.type ~= "sentence" then
        yield(snow.prepare(candidate, proxy, true))
      end
    end
  end
end

local lianxiang = {}

---@param env ProxyTranslatorEnv
function lianxiang.init(env)
  env.translator = Component.Translator(env.engine, "jianpin2", "script_translator")
end

---@param input string
---@param segment Segment
---@param env ProxyTranslatorEnv
function lianxiang.func(input, segment, env)
  -- 多字词
  if env.engine.context:get_option("popping1") and input:len() == 3 then
    local proxy = ("%s %s %s ~"):format(input:sub(1,1), input:sub(2,2), input:sub(3,3))
    local translation = env.translator:query(proxy, segment)
    for candidate in translation:iter() do
      if candidate.type ~= "sentence" then
        yield(snow.prepare(candidate, proxy, true))
      end
    end
  end
end

---@param env ProxyTranslatorEnv
function lianxiang.fini(env)
  env.translator = nil
  collectgarbage()
end

return {
  t12 = t12,
  jianpin = jianpin,
  lianxiang = lianxiang,
}

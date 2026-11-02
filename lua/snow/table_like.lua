-- 模拟码表翻译器
-- 将冰雪三拼的词编码转换为逐音节代理码，交给原生拼音翻译器查询

local snow = require "snow.snow"

---@class TableLikeEnv: Env
---@field translator Translator
---@field pattern string
---@field pattern2 string

---@param proxy string
---@param segment Segment
---@param env TableLikeEnv
---@param accept? fun(candidate: Candidate): boolean
---@param complete_only? boolean
local function translate(proxy, segment, env, accept, complete_only)
  -- 代理码不是合法拼写时 query 返回 nil，这一路当作没有候选
  local translation = env.translator:query(proxy, segment)
  if not translation then
    return
  end
  for candidate in translation:iter() do
    -- 原生 script_translator 按消耗长度降序输出；简拼只查完整编码，
    -- 遇到短片段即可结束，避免把成千上万个前缀候选取到 Lua 再逐个丢弃。
    if complete_only and candidate._end - candidate._start < proxy:len() then
      return
    end
    snow.prepare(candidate, proxy)
    if not accept or accept(candidate) then
      yield(candidate)
    end
  end
end

local t12 = {}

---@param env TableLikeEnv
function t12.init(env)
  -- 翻译器持有 engine，不能跨会话共享，否则原会话销毁后会访问失效的引擎
  env.translator = Component.Translator(env.engine, "translator", "script_translator")
  env.pattern = env.engine.schema.config:get_string("translator/t1_pattern") or "^.+$"
  env.pattern2 = env.engine.schema.config:get_string("translator/t2_pattern") or "^.+$"
end

---@param input string
---@param segment Segment
---@param env TableLikeEnv
function t12.func(input, segment, env)
  -- 六码二字词选完首字后，剩下「声₂韵₂调₂调₁」。末码已记在首字读音里，
  -- 查第二字时忽略它，确认时一并消耗；原始输入不变，退格仍可撤销首字选择。
  local previous = env.engine.context.composition:toSegmentation():get_at(-2)
  local selected = previous and previous:get_selected_candidate()
  if previous and previous._end == segment.start and selected
      and selected:get_genuine().type == "sanpin_partial" and input:len() == 4 then
    translate(input:sub(1, -2), segment, env, function(candidate)
      if candidate._end ~= segment._end - 1 then
        return false
      end
      candidate._end = segment._end
      return true
    end)
    return
  end
  -- 一字词与整句模式
  if rime_api.regex_match(input, env.pattern) or not env.engine.context:get_option("popping") then
    translate(input, segment, env)
  end
  -- 二字词
  if rime_api.regex_match(input, env.pattern2) then
    local proxy = ("%s %s"):format(input:sub(1, 2), input:sub(3))
    if input:len() == 6 then
      proxy = ("%s%s %s"):format(input:sub(1, 2), input:sub(-1, -1), input:sub(3, -2))
    end
    translate(proxy, segment, env, function(candidate)
      local length = utf8.len(candidate.text)
      if length == 1 and input:len() == 6 and candidate._end == segment.start + 3 then
        -- 首字只消耗连续的声韵两码，其声调仍留在原始输入的末尾。
        candidate._end = segment.start + 2
        candidate.type = "sanpin_partial"
        candidate.preedit = input:sub(1, 2) .. " "
      end
      return length <= 2
    end)
  end
end

---@param env TableLikeEnv
function t12.fini(env)
  env.translator = nil
  collectgarbage()
end

local jianpin = {}

---@param env TableLikeEnv
function jianpin.init(env)
  env.translator = Component.Translator(env.engine, "jianpin", "script_translator")
  env.pattern = env.engine.schema.config:get_string("translator/jianpin_pattern") or "^.+$"
end

---@param input string
---@param segment Segment
---@param env TableLikeEnv
function jianpin.func(input, segment, env)
  if not rime_api.regex_match(input, env.pattern) then
    return
  end
  local proxy = input:gsub("[viuoa]", "")
  local buma = input:gsub("[bpmfdtnlgkhjqxzcsrywe]", "")
  local initial_count = proxy:len()
  -- 后置声调依次分配给最后、第一、第二个音节
  proxy = proxy:gsub("()([a-z])", function(i, initial)
    local tone = i == initial_count and buma:sub(1, 1) or buma:sub(i + 1, i + 1)
    return initial .. (tone ~= "" and "?" .. tone or "")
  end)
  translate(proxy, segment, env, function(candidate)
    return utf8.len(candidate.text) >= initial_count and candidate.type ~= "sentence"
  end, true)
end

---@param env TableLikeEnv
function jianpin.fini(env)
  env.translator = nil
  collectgarbage()
end

return {
  t12 = t12,
  jianpin = jianpin,
}

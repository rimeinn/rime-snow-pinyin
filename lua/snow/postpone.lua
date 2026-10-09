-- 后置过滤器
-- 本过滤器记录码长较短时已出现在首选的字词，当码长较长时将这些字词后置，以便提高编码的利用效率

local snow = require "snow.snow"

local filter = {}

---@class PostponeEnv: Env
---@field known_candidates table<string, number>
---@field disable string

---@param env PostponeEnv
function filter.init(env)
  env.known_candidates = {}
  env.disable = env.engine.schema.config:get_string("translator/disable_postpone_pattern") or ""
end

---@param segment Segment
---@param env Env
function filter.tags_match(segment, env)
  local context = env.engine.context
  -- 在回补时不刷新
  if context.caret_pos ~= context.input:len() then
    return false
  end
  return context:get_option("popping") and segment:has_tag("abc")
end

---@param known_candidates table<string, number>
local function format_known_candidates(known_candidates)
  local parts = {}
  for k, v in pairs(known_candidates) do
    table.insert(parts, string.format("%s:%d", k, v))
  end
  return "{" .. table.concat(parts, ", ") .. "}"
end

---@param list Candidate[]
local function format_candidate_list(list)
  local result = {}
  for _, cand in ipairs(list) do
    table.insert(result, cand.text)
  end
  return table.concat(result, ", ")
end

---@param postponed_candidates Candidate[]
---@param regular_candidates Candidate[]
---@param final_table Candidate[]
---@param input string
---@param env PostponeEnv
function filter.finalize(postponed_candidates, regular_candidates, final_table, input, env)
  ---@type Candidate[]
  local merged_candidates = { regular_candidates[1] }
  table.sort(postponed_candidates, function(a, b)
    return env.known_candidates[a.text] > env.known_candidates[b.text]
  end)
  for i = 1, #postponed_candidates do
    table.insert(merged_candidates, postponed_candidates[i])
  end
  for i = 2, #regular_candidates do
    table.insert(merged_candidates, regular_candidates[i])
  end
  local merged_index = 1
  for i = 1, #final_table do
    if final_table[i].text == snow.placeholder and merged_index <= #merged_candidates then
      final_table[i] = merged_candidates[merged_index]
      merged_index = merged_index + 1
    end
  end
  local first = final_table[1]
  if not rime_api.regex_match(input, env.disable) then
    env.known_candidates[first.text] = input:len()
  end
  for _, candidate in ipairs(final_table) do
    if candidate.text ~= snow.placeholder then
      yield(candidate)
    end
  end
end

---@param translation Translation
---@param env PostponeEnv
function filter.func(translation, env)
  local context = env.engine.context
  local segment = context.composition:toSegmentation():back()
  -- 取出输入中当前正在翻译的一部分
  local input = snow.current(context)
  if not input or not segment then
    for candidate in translation:iter() do
      yield(candidate)
    end
    return
  end
  local full_input = input
  local shape_input = context:get_property("shape_input")
  if shape_input then
    full_input = input .. shape_input
  end
  -- 删除与当前编码长度相等或者更长的已知候选，这些对当前输入无帮助
  for k, v in pairs(env.known_candidates) do
    if v >= full_input:len() then
      env.known_candidates[k] = nil
    end
  end

  -- 设当前编码长度为 n，则：
  -- 过滤开始前，known_candidates 包含 n-1 项，分别是 1 ~ n-1 长度时对应的首选
  -- 过滤结束后，known_candidates 包含 n 项，分别是 1 ~ n 长度时对应的首选

  -- 用于存放需要后置的候选
  ---@type Candidate[]
  local postponed_candidates = {}
  ---@type Candidate[]
  local regular_candidates = {}

  -- 过滤分为两个阶段：
  -- 1. 检视前 10 个候选，并将其分为两类：一是在之前的首选中出现的候选，二是没有出现过的候选。将其重排为以下的顺序：（1）没出现过的候选中的第一个；（2）出现过的候选按码长降序排列（例如，有几个候选分别在 2, 3, 5 码出现过，那么按照 5, 3, 2 的顺序输出）；（3）没出现过的候选中的剩余候选。
  -- 2. 第 10 个以后的候选原样输出
  -- 这个过滤器会位于固定过滤器之后，因此对于已经固定的候选则不会调整位置
  local seen_candidates = 0
  local max_candidates = 10
  local finalized = false
  ---@type Candidate[]
  local final_table = {}
  for i = 1, max_candidates do
    table.insert(final_table, Candidate("", segment.start, segment._end, snow.placeholder, ""))
  end
  for candidate in translation:iter() do
    local text = candidate.text
    if finalized then
      yield(candidate)
    elseif seen_candidates == max_candidates or (candidate._end - candidate._start) < input:len() then
      filter.finalize(postponed_candidates, regular_candidates, final_table, full_input, env)
      finalized = true
      yield(candidate)
    elseif candidate.comment:match("📌") or candidate.comment:match("📍") then -- 固定候选不调整位置
      final_table[seen_candidates + 1] = candidate
    elseif (env.known_candidates[text] or math.huge) < full_input:len() then -- 如果这个候选词已经在首选中出现过，那么后置
      table.insert(postponed_candidates, candidate)
    else -- 否则暂存
      table.insert(regular_candidates, candidate)
    end
    seen_candidates = seen_candidates + 1
  end
  if not finalized then
    filter.finalize(postponed_candidates, regular_candidates, final_table, full_input, env)
  end
end

return filter

-- 日期与时间翻译器
-- 输入特定的日期时间缩写，输出对应的日期时间字符串

---@param input string
---@param seg Segment
---@param env Env
local function translator(input, seg, env)
  local lua_prompt = env.engine.schema.config:get_string("lua/input") or "o"
  if input:sub(1, 1) ~= lua_prompt then
    return
  end
  local command = input:sub(2)
  ---@type (string | osdate)[]
  local datetimes = {}
  if (command == "rq") then
    table.insert(datetimes, os.date("%Y年%m月%d日"))
    table.insert(datetimes, os.date("%Y-%m-%d"))
  elseif (command == "sj") then
    table.insert(datetimes, os.date("%H时%M分%S秒"))
    table.insert(datetimes, os.date("%H:%M:%S"))
  elseif (command == "rs") then
    table.insert(datetimes, os.date("%Y年%m月%d日%H时%M分%S秒"))
    table.insert(datetimes, os.date("%Y-%m-%d %H:%M:%S"))
  end
  for _, entry in ipairs(datetimes) do
    ---@cast entry string
    yield(Candidate("datetime", seg.start, seg._end, entry, ""))
  end
end

return translator

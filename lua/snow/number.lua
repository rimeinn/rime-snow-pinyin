-- 数字翻译器
-- 将阿拉伯数字翻译为大小写汉字，数字与 sbqwnyr 的组合逐字翻译为十百千万年月日

---@class NumberEnv: Env
---@field prompt string

local translator = {}

local lower = { [0] = "零", "一", "二", "三", "四", "五", "六", "七", "八", "九" }
local upper = { [0] = "零", "壹", "贰", "叁", "肆", "伍", "陆", "柒", "捌", "玖" }
local lower_units = { [0] = "", "十", "百", "千" }
local upper_units = { [0] = "", "拾", "佰", "仟" }
local big_units = { [0] = "", "万", "亿", "万亿", "亿亿" }
local letters = { s = "十", b = "百", q = "千", w = "万", n = "年", y = "月", r = "日" }
local traditional = { ["万"] = "萬", ["亿"] = "億", ["贰"] = "貳", ["叁"] = "參", ["陆"] = "陸" }

---@param n string 不含前导零的数字串
---@param digits string[]
---@param units string[]
local function read(n, digits, units)
  local s = ""
  for i = 1, #n do
    local d, p = tonumber(n:sub(i, i)), #n - i
    if d > 0 then
      s = s .. digits[d] .. units[p % 4]
    elseif p % 4 > 0 and n:sub(i + 1, i + 1) ~= "0" then
      s = s .. digits[0]
    end
    if p % 4 == 0 and n:sub(math.max(i - 3, 1), i):find("[1-9]") then
      s = s .. big_units[p // 4]
    end
  end
  return s == "" and digits[0] or s
end

---@param env NumberEnv
function translator.init(env)
  env.prompt = env.engine.schema.config:get_string("lua/input") or "o"
end

---@param input string
---@param segment Segment
---@param env NumberEnv
function translator.func(input, segment, env)
  if input:sub(1, #env.prompt) ~= env.prompt then
    return
  end
  local n = input:sub(#env.prompt + 1)
  local results = {}
  if n:find("^%d+$") then
    n = n:gsub("^0+", "")
    if #n > 20 then
      return
    end
    local small, big = read(n, lower, lower_units), read(n, upper, upper_units)
    results = {
      { small, " 小写" },
      { big, " 大写" },
      { small:gsub(utf8.charpattern, traditional), " 小寫" },
      { big:gsub(utf8.charpattern, traditional), " 大寫" },
    }
  elseif n:find("^[%dsbqwnyr]+$") and n:find("%d%a") then
    local text = n:gsub("%d", function (c) return lower[tonumber(c)] end):gsub("%a", letters)
    results = { { text, "" } }
    if text:find("零") then
      table.insert(results, { (text:gsub("零", "〇")), "" })
    end
  end
  for _, result in ipairs(results) do
    yield(Candidate("number", segment.start, segment._end, result[1], result[2]))
  end
end

return translator

-- 数字翻译器
-- 将 `o` + 阿拉伯数字 翻译为大小写汉字

local datechars = {
  ["0"] = "零",
  ["1"] = "一",
  ["2"] = "二",
  ["3"] = "三",
  ["4"] = "四",
  ["5"] = "五",
  ["6"] = "六",
  ["7"] = "七",
  ["8"] = "八",
  ["9"] = "九",
  ["s"] = "十",
  ["b"] = "百",
  ["q"] = "千",
  ["w"] = "万",
  ["n"] = "年",
  ["y"] = "月",
  ["r"] = "日",
}

local confs = {
  {
    comment = " 小写",
    number = { [0] = "零", "一", "二", "三", "四", "五", "六", "七", "八", "九" },
    suffix = { [0] = "", "十", "百", "千" },
    suffix2 = { [0] = "", "万", "亿", "万亿", "亿亿" }
  },
  {
    comment = " 大写",
    number = { [0] = "零", "壹", "贰", "叁", "肆", "伍", "陆", "柒", "捌", "玖" },
    suffix = { [0] = "", "拾", "佰", "仟" },
    suffix2 = { [0] = "", "万", "亿", "万亿", "亿亿" }
  },
  {
    comment = " 小寫",
    number = { [0] = "零", "一", "二", "三", "四", "五", "六", "七", "八", "九" },
    suffix = { [0] = "", "十", "百", "千" },
    suffix2 = { [0] = "", "萬", "億", "萬億", "億億" }
  },
  {
    comment = " 大寫",
    number = { [0] = "零", "壹", "貳", "參", "肆", "伍", "陸", "柒", "捌", "玖" },
    suffix = { [0] = "", "拾", "佰", "仟" },
    suffix2 = { [0] = "", "萬", "億", "萬億", "億億" }
  },
}

local function todatechars(datechars, input)
  local r = ""
  for c in input:gmatch("%w") do
    ---@type string
    r = r .. datechars[c]
  end
  return r
end

local function read_seg(conf, n)
  local s = ""
  local i = 0
  local zf = true

  while n:len() > 0 do
    local d = tonumber(n:sub(-1, -1))
    if d ~= 0 then
      ---@type string
      s = conf.number[d] .. conf.suffix[i] .. s
      zf = false
    else
      if not zf then
        ---@type string
        s = conf.number[0] .. s
      end
      zf = true
    end
    i = i + 1
    n = n:sub(1, -2)
  end

  return i < 4, s
end

local function read_number(conf, n)
  local s = ""
  local i = 0
  local zf = false

  n = n:gsub("^0+", "")

  if n == "" then
    return conf.number[0]
  end

  while n:len() > 0 do
    local zf2, r = read_seg(conf, n:sub(-4, -1))
    if r ~= "" then
      if zf and s ~= "" then
        ---@type string
        s = r .. conf.suffix2[i] .. conf.number[0] .. s
      else
        ---@type string
        s = r .. conf.suffix2[i] .. s
      end
    end
    zf = zf2
    i = i + 1
    n = n:sub(1, -5)
  end
  return s
end

local translator = {}

---@class NumberEnv: Env
---@field prompt string

---@param env NumberEnv
function translator.init(env)
  env.prompt = env.engine.schema.config:get_string("lua/input") or "o"
end

---@param input string
---@param segment Segment
---@param env NumberEnv
function translator.func(input, segment, env)
  if input:sub(1, 1) ~= env.prompt then
    return
  end
  local n = input:sub(2)
  if tonumber(n) ~= nil then
    for _, conf in ipairs(confs) do
      local r = read_number(conf, n)
      yield(Candidate("number", segment.start, segment._end, r, conf.comment))
    end
  elseif n:find("[0-9]+%a") ~= nil then
    local d = todatechars(datechars, n)
    if d ~= nil then
      yield(Candidate("number", segment.start, segment._end, d, ""))
      if d:find("零") then
        local d2 = d:gsub("零", "〇")
        yield(Candidate("number", segment.start, segment._end, d2, ""))
      end
    end
  end
end

return translator

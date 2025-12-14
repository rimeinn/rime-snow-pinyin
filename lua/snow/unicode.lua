-- Unicode 过滤器
-- 为候选加上 Unicode 和分区信息

local snow = require("snow.snow")

local filter = {}

local unicodeBlocks = {
  -- 统一汉字基本集与扩展
  {
    name = "CJK",
    begin = 0x4e00,
    finish = 0x9fff,
  },
  {
    name = "CJK-A",
    begin = 0x3400,
    finish = 0x4dbf,
  },
  {
    name = "CJK-B",
    begin = 0x20000,
    finish = 0x2a6df,
  },
  {
    name = "CJK-C",
    begin = 0x2a700,
    finish = 0x2b73f,
  },
  {
    name = "CJK-D",
    begin = 0x2b740,
    finish = 0x2b81f,
  },
  {
    name = "CJK-E",
    begin = 0x2b820,
    finish = 0x2ceaf,
  },
  {
    name = "CJK-F",
    begin = 0x2ceb0,
    finish = 0x2ebef,
  },
  {
    name = "CJK-G",
    begin = 0x30000,
    finish = 0x3134f,
  },
  {
    name = "CJK-H",
    begin = 0x31350,
    finish = 0x323af,
  },
  {
    name = "CJK-I",
    begin = 0x2ebf0,
    finish = 0x2ee5f,
  },

  -- 部件
  {
    name = "部首补充",
    begin = 0x2e80,
    finish = 0x2eff,
  },
  {
    name = "部首",
    begin = 0x2f00,
    finish = 0x2fdf,
  },
  {
    name = "笔画",
    begin = 0x31c0,
    finish = 0x31ef,
  },

  -- 兼容汉字
  {
    name = "兼容",
    begin = 0xf900,
    finish = 0xfaff,
  },
  {
    name = "兼容补充",
    begin = 0x2f800,
    finish = 0x2fa1f,
  },

  -- 古文字系统
  {
    name = "西夏",
    begin = 0x17000,
    finish = 0x187ff,
  },
  {
    name = "西夏构件",
    begin = 0x18800,
    finish = 0x18aff,
  },
  {
    name = "西夏补充",
    begin = 0x18d00,
    finish = 0x18d7f,
  },
  {
    name = "契丹",
    begin = 0x18b00,
    finish = 0x18cff,
  },

  -- 标点符号与排版字符
  {
    name = "符号",
    begin = 0x3000,
    finish = 0x303f,
  },
  {
    name = "带圈",
    begin = 0x3200,
    finish = 0x32ff,
  },
  {
    name = "带圈补充",
    begin = 0x1f200,
    finish = 0x1f2ff,
  },
  {
    name = "符号",
    begin = 0x16fe0,
    finish = 0x16fff,
  },
};

---@param env Env
function filter.init(env)
  -- 初始化可以放一些预处理代码
end

---@param segment Segment
---@param env Env
function filter.tags_match(segment, env)
  return env.engine.context:get_option("unicode")
end

function filter.get_block_name(codepoint)
  for _, block in ipairs(unicodeBlocks) do
    if codepoint >= block.begin and codepoint <= block.finish then
      return block.name
    end
  end
  return "未知分区"
end

---@param translation Translation
---@param env Env
function filter.func(translation, env)
  for candidate in translation:iter() do
    local codepoint = utf8.codepoint(candidate.text)
    if utf8.len(candidate.text) == 1 and codepoint and codepoint >= 0x80 then
      local block_name = filter.get_block_name(codepoint)
      snow.comment(candidate, ("%04X %s"):format(codepoint, block_name))
    end
    yield(candidate)
  end
end

return filter

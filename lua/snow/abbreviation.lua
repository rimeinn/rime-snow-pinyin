-- 略码处理器

local snow = require "snow.snow"

local processor = {}

local lookup = {
  ["D"] = "的",
  ["L"] = "了",
  ["B"] = "不",
  ["F"] = "一",
  ["R"] = "啊",
  ["U"] = "呀",
}

---@param key_event KeyEvent
---@param env Env
function processor.func(key_event, env)
  local context = env.engine.context
  local selection = context:get_selected_candidate()
  if not selection then
    return snow.kNoop
  end
  local length = utf8.len(selection.text)
  if length >= 4 then
    return snow.kNoop
  end
  if key_event:release() or key_event:alt() or key_event:ctrl() or key_event:caps() then
    return snow.kNoop
  end
  local incoming = utf8.char(key_event.keycode)
  local text = selection.text
  -- 重复出来的部分，分别接在这个词的前面和后面
  local before, after = "", ""
  if incoming == "[" and length == 1 or incoming == "A" then -- 重复一字词、多字词
    after = text
  elseif lookup[incoming] ~= nil then -- 重复并插入
    after = lookup[incoming] .. text
  elseif incoming == "E" then -- 重复词的首字
    before = snow.sub(text, 1, 1)
  elseif incoming == "I" then -- 重复词的末字
    after = snow.sub(text, -1, -1)
  elseif incoming == "O" and length == 2 then -- 叠词重复二字词
    before, after = snow.sub(text, 1, 1), snow.sub(text, -1, -1)
  elseif incoming == "W" then -- Ａ着Ａ着
    after = "着" .. text .. "着"
  elseif incoming == "Q" then -- Ａ来Ａ去
    after = "来" .. text .. "去"
  else
    return snow.kNoop
  end
  -- 输入统计把重复出来的部分合起来记作一次上屏，略码键是它的编码，像顶功那样转给它
  snow.commit_text(env.engine, before, "")
  snow.handover = 1
  context:confirm_current_selection()
  context:commit()
  snow.handover = nil
  snow.commit_text(env.engine, after, before .. after)
  return snow.kAccepted
end

return processor

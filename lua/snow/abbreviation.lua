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
  if incoming == "[" and length == 1 then -- 重复一字词
    context:confirm_current_selection()
    context:commit()
    snow.commit_text(env.engine, selection.text)
  elseif lookup[incoming] ~= nil then -- 重复并插入
    context:confirm_current_selection()
    context:commit()
    snow.commit_text(env.engine, lookup[incoming])
    snow.commit_text(env.engine, selection.text)
  elseif incoming == "E" or incoming == "I" then -- 重复词的首字或末字
    if incoming == "E" then
      snow.commit_text(env.engine, snow.sub(selection.text, 1, 1))
    end
    context:confirm_current_selection()
    context:commit()
    if incoming == "I" then
      snow.commit_text(env.engine, snow.sub(selection.text, -1, -1))
    end
  elseif incoming == "A" then -- 重复多字词
    context:confirm_current_selection()
    context:commit()
    snow.commit_text(env.engine, selection.text)
  elseif incoming == "O" and length == 2 then -- 叠词重复二字词
    snow.commit_text(env.engine, snow.sub(selection.text, 1, 1))
    context:confirm_current_selection()
    context:commit()
    snow.commit_text(env.engine, snow.sub(selection.text, -1, -1))
  elseif incoming == "W" then -- Ａ着Ａ着
    context:confirm_current_selection()
    context:commit()
    snow.commit_text(env.engine, "着" .. selection.text .. "着")
  elseif incoming == "Q" then -- Ａ来Ａ去
    context:confirm_current_selection()
    context:commit()
    snow.commit_text(env.engine, "来" .. selection.text .. "去")
  else
    return snow.kNoop
  end
  return snow.kAccepted
end

return processor

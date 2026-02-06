-- 并击顶功处理器
-- 由于 Rime chord_composer 的特殊性，不能复用串击的顶功处理器

local snow = require "snow.snow"

local processor = {}

---@class ComboPoppingEnv: Env
---@field active boolean

---@param env ComboPoppingEnv
function processor.init(env)
  env.active = true
end

---@param key_event KeyEvent
---@param env ComboPoppingEnv
function processor.func(key_event, env)
  local incoming = utf8.char(key_event.keycode)
  local context = env.engine.context
  if key_event:release() or key_event:alt() or key_event:ctrl() or key_event:caps() then
    return snow.kNoop
  end
  -- 取出输入中当前正在翻译的一部分
  local input = snow.current(context) or ""
  if rime_api.regex_match(input, "([bpmfdtnlgkhzcsr]j?[iuv]?(a|ai|an|ang|ao|e|ei|en|eng|ou)?[wyxq])*") then
    if incoming == "u" then -- 在完整音节后面出现 u，表示追加
      env.active = false
      return snow.kAccepted
    elseif incoming == "i" or incoming == "o" then -- 在完整音节后面出现 i，表示标点符号
      context:confirm_current_selection()
      context:commit()
      return incoming == "i" and snow.kNoop or snow.kAccepted
    elseif rime_api.regex_match(incoming, "[a-z]") then
      if env.active and context:get_option("popping") then
        context:confirm_current_selection()
        context:commit()
      else
        env.active = true
      end
    end
    return snow.kNoop
  else
    return snow.kNoop
  end
end

return processor

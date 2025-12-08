-- 以词定字
-- https://github.com/BlindingDark/rime-lua-select-character

local snow = require "snow.snow"

local select = {}

---@class SelectCharacterEnv: Env
---@field first_key KeyEvent
---@field last_key KeyEvent

---@param env SelectCharacterEnv
function select.init(env)
  local config = env.engine.schema.config
  env.first_key = KeyEvent(config:get_string("key_binder/select_first_character") or "bracketleft")
  env.last_key = KeyEvent(config:get_string("key_binder/select_last_character") or "bracketright")
end

---@param key KeyEvent
---@param env SelectCharacterEnv
function select.func(key, env)
  local engine = env.engine
  local context = env.engine.context

  if key.modifier > 0 or (not context:has_menu()) then
    return snow.kNoop
  end
  local text = ""
  if context:get_selected_candidate() then
    text = context:get_selected_candidate().text
  end
  if utf8.len(text) > 1 then
    if key:eq(env.first_key) then
      engine:commit_text(text:sub(1, utf8.offset(text, 2) - 1))
      context:clear()
      return snow.kAccepted
    elseif key:eq(env.last_key) then
      engine:commit_text(text:sub(utf8.offset(text, -1)))
      context:clear()
      return snow.kAccepted
    end
  end
  return snow.kNoop
end

return select

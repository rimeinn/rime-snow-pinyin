-- 辅助码处理器
-- 本处理器接受辅助码按键，把它们放到上下文中

local snow = require "snow.snow"

---@param env Env
local function update(env)
  local composition = env.engine.context.composition
  if composition:empty() then
    return
  end
  local segment = composition:back()
  segment.prompt = segment.prompt .. ": " .. (env.engine.context:get_property("shape_input") or "")
  env.engine.context:refresh_non_confirmed_composition()
end

---@class ShapeConfig
---@field match string?
---@field match_shape string?
---@field accept string

---@class ShapeEnv: Env
---@field config ShapeConfig[]

local processor = {}

---@param env ShapeEnv
function processor.init(env)
  local function clear()
    env.engine.context:set_property("shape_input", "")
    env.engine.context:set_property("shape_status", "")
    update(env)
  end
  local context = env.engine.context
  context.select_notifier:connect(clear)
  context.commit_notifier:connect(clear)
  local shape_config = env.engine.schema.config:get_list("speller/shape")
  if not shape_config then
    return
  end
  env.config = {}
  for i = 1, shape_config.size do
    local item = shape_config:get_at(i - 1)
    if not item then goto continue end
    local value = item:get_map()
    if not value then goto continue end
    local match = value:get_value("match")
    local match_shape = value:get_value("match_shape")
    ---@type ShapeConfig
    local parsed = {
      match = match and match:get_string(),
      match_shape = match_shape and match_shape:get_string(),
      accept = value:get_value("accept"):get_string(),
    }
    table.insert(env.config, parsed)
    ::continue::
  end
end

---@param key KeyEvent
---@param env ShapeEnv
function processor.func(key, env)
  local input = snow.current(env.engine.context) or ""
  if input:len() == 0 then
    env.engine.context:set_property("shape_input", "")
  end
  -- 追加编码
  local context = env.engine.context
  local shape_input = context:get_property("shape_input")
  local key_char = utf8.char(key.keycode)
  if key.keycode == snow.kBackSpace and shape_input ~= "" then
    if env.engine.schema.schema_id == "snow_yipin" then
      shape_input = ""
    else
      shape_input = shape_input:sub(1, -2)
    end
    goto update
  else
    for _, rule in ipairs(env.config) do
      if rule.match and not rime_api.regex_match(input, rule.match) then
        goto continue
      end
      if rule.match_shape and not rime_api.regex_match(shape_input, rule.match_shape) then
        goto continue
      end
      if not rime_api.regex_match(key_char, rule.accept) then
        goto continue
      end
      shape_input = shape_input .. key_char
      goto update
      ::continue::
    end
    return snow.kNoop
  end
  ::update::
  context:set_property("shape_input", shape_input)
  update(env)
  return snow.kAccepted
end

return processor

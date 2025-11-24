-- 顶功处理器
-- 本处理器能够支持所有的规则顶功模式
-- 根据当前编码和新输入的按键来决定是否将当前编码或其一部分的首选顶上屏

local snow = require "snow.snow"

local this = {}

local strategies = {
  pop = "pop",
  append = "append",
  conditional = "conditional"
}

---@class PoppingConfig
---@field when string
---@field match string
---@field accept string
---@field prefix number
---@field strategy string

---@class PoppingEnv: Env
---@field popping PoppingConfig[]
---@field processing boolean

---@param env PoppingEnv
function this.init(env)
  env.engine.context.option_update_notifier:connect(function(ctx, name)
    if name == "buffered" then
      local buffered = ctx:get_option("buffered")
      ctx:set_option("_auto_commit", not buffered)
    end
  end)
  env.engine.context.commit_notifier:connect(function(ctx)
    if ctx:get_option("buffered") then
      ctx:set_option("buffered", false)
    end
  end)
  local config = env.engine.schema.config
  local popping_config = config:get_list("speller/popping")
  if not popping_config then
    return
  end
  ---@type PoppingConfig[]
  env.popping = {}
  for i = 1, popping_config.size do
    local item = popping_config:get_at(i - 1)
    if not item then goto continue end
    local value = item:get_map()
    if not value then goto continue end
    local popping = {
      when = value:get_value("when") and value:get_value("when"):get_string(),
      match = value:get_value("match"):get_string(),
      accept = value:get_value("accept"):get_string(),
      prefix = value:get_value("prefix") and value:get_value("prefix"):get_int(),
      strategy = value:get_value("strategy") and value:get_value("strategy"):get_string()
    }
    if popping.strategy ~= nil and strategies[popping.strategy] == nil then
      snow.errorf("Invalid popping strategy: %s", popping.strategy)
      goto continue
    end
    table.insert(env.popping, popping)
    ::continue::
  end
end

---@param key_event KeyEvent
---@param env PoppingEnv
function this.func(key_event, env)
  if env.processing then
    return snow.kNoop
  end
  local context = env.engine.context
  local buffered = context:get_option("buffered")
  if key_event:release() or key_event:alt() or key_event:ctrl() or key_event:caps() then
    return snow.kNoop
  end
  local incoming = key_event:repr()
  -- 如果输入为空格或数字，代表着作文即将上屏，此时把 kConfirmed 的片段改为 kSelected
  -- 这解决了 https://github.com/rime/home/issues/276 中的不造词问题
  if rime_api.regex_match(incoming, "\\d") or incoming == "space" then
    for _, segment in ipairs(context.composition:toSegmentation():get_segments()) do
      if segment.status == snow.kConfirmed then
        segment.status = snow.kSelected
      end
    end
  end
  -- 取出输入中当前正在翻译的一部分
  local input = snow.current(context)
  if not input then
    return snow.kNoop
  end
  local shape_input = context:get_property("shape_input")
  if shape_input then
    input = input .. shape_input
  end
  -- Rime 有一个 bug，在按句号键之后的那个字词的编码的会有一个隐藏的 "."
  -- 这导致顶功判断失败，所以先屏蔽了。但是这个对用 "." 作为编码的方案会有影响
  if input == "." then
    context:pop_input(1)
    input = snow.current(context)
    if not input then
      return snow.kNoop
    end
  end
  local with_punct = false
  local incoming = utf8.char(key_event.keycode)
  for _, rule in ipairs(env.popping) do
    local when = rule.when
    local success = false
    if when and not context:get_option(when) then
      goto continue
    end
    if not rime_api.regex_match(input, rule.match) then
      goto continue
    end
    if not rime_api.regex_match(incoming, rule.accept) then
      goto continue
    end
    -- 如果策略为追加编码，则不执行顶屏直接返回
    if rule.strategy == strategies.append then
      with_punct = true
      goto finish
      -- 如果策略为条件顶屏，那么尝试先添加编码，如果能匹配到候选就不顶屏
    elseif rule.strategy == strategies.conditional then
      context:push_input(incoming)
      if context:has_menu() then
        context:pop_input(1)
        goto finish
      end
      context:pop_input(1)
    end
    if rule.prefix then
      context:pop_input(input:len() - rule.prefix)
    end
    -- 如果当前有候选，则执行顶屏；否则顶功失败，继续执行下一个规则
    if context:has_menu() then
      context:confirm_current_selection()
      if not buffered then
        context:commit()
      end
      success = true
    end
    if rule.prefix then
      context:push_input(input:sub(rule.prefix + 1))
    end
    if success then
      goto finish
    end
    ::continue::
  end
  ::finish::
  -- 大写字母执行完顶屏功能之后转成小写
  local map = {
    [string.byte(":")] = string.byte(";"),
    [string.byte("<")] = string.byte(","),
    [string.byte(">")] = string.byte("."),
    [string.byte("?")] = string.byte("/")
  }
  if key_event.keycode >= 65 and key_event.keycode <= 90 then
    key_event = KeyEvent(utf8.char(key_event.keycode + 32))
  elseif with_punct and map[key_event.keycode] then
    key_event = KeyEvent(utf8.char(map[key_event.keycode]))
  end
  env.processing = true
  env.engine:process_key(key_event)
  env.processing = false
  return snow.kAccepted
end

return this

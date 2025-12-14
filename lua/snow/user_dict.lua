-- 用户词典处理器
-- 本处理器可帮助用户便捷地更改方案码用户词典
-- 在编写过程中主要参考了露台和魔然的相关实现

local snow = require "snow.snow"

local this = {}

---@class UserDbEnv: Env
---@field dict table<string, string[]>
---@field user_dict LevelDb
---@field add_word string
---@field add_input string
---@field add_index integer
---@field connection Connection
---@field fix_key KeyEvent
---@field add_key KeyEvent
---@field up_key KeyEvent
---@field down_key KeyEvent
---@field reset_key KeyEvent

---@param env UserDbEnv
function this.init(env)
  local config = env.engine.schema.config
  env.dict = snow.read_dictionary(snow.get_dictionary_path(env))
  if config:get_bool("translator/enable_schema_user_dict") then
    env.user_dict = snow.get_db(env.engine.schema.schema_id)
  end
  env.add_word = ""
  env.add_input = ""
  env.add_index = 0
  env.fix_key = KeyEvent("Control+semicolon")
  env.add_key = KeyEvent("Control+apostrophe")
  env.up_key = KeyEvent("Control+bracketleft")
  env.down_key = KeyEvent("Control+bracketright")
  env.reset_key = KeyEvent("Control+backslash")
  for _, field in ipairs({ "fix_key", "add_key", "up_key", "down_key", "reset_key" }) do
    local repr = config:get_string("translator/" .. field)
    if repr then
      ---@diagnostic disable-next-line: no-unknown
      env[field] = KeyEvent(repr)
    end
  end
  env.connection = env.engine.context.commit_notifier:connect(function(ctx)
    if env.add_input:len() > 0 then
      local text = ctx:get_commit_text()
      if text and text ~= "" then
        env.add_word = env.add_word .. text
        snow.errorf("正在添加新词：%s", env.add_word)
      end
    end
  end)
end

---@param candidate Candidate
function this.is_fixed(candidate)
  local comment = candidate.comment
  if comment:match(snow.fixed_symbol) or comment:match(snow.fixed_notfound_symbol) then
    return true
  end
  return false
end

---@param input string
---@param index integer
---@param new_index integer
---@param env UserDbEnv
function this.check_move(input, index, new_index, env)
  local segment = env.engine.context.composition:toSegmentation():back()
  if not segment then
    return
  end
  local candidate = segment:get_candidate_at(index - 1)
  if this.is_fixed(candidate) then
    local epoch = snow.epoch()
    local word = candidate.text
    local key = snow.key(input, word)
    local value = snow.format(snow.encode(epoch, new_index))
    env.user_dict:update(key, value)
    snow.errorf("时间戳 %d：「%s」在 %s 候选 %d → %d", epoch, word, input, index, new_index)
  end
end

---@param context Context
---@param index integer
function this.refresh_recover(context, index)
  context:refresh_non_confirmed_composition()
  local segment = context.composition:toSegmentation():back()
  segment.selected_index = index - 1
end

---@param env UserDbEnv
function this.get_first_available_index(env)
  local segment = env.engine.context.composition:toSegmentation():back()
  if not segment then
    return nil
  end
  for index = 1, snow.MAX_INDEX do
    local candidate = segment:get_candidate_at(index - 1)
    if not candidate then
      return index
    end
    if not this.is_fixed(candidate) then
      return index
    end
  end
  return nil
end

---@param key_event KeyEvent
---@param env UserDbEnv
function this.func(key_event, env)
  local context = env.engine.context
  local config = env.engine.schema.config
  if not config:get_bool("translator/enable_schema_user_dict") then
    return snow.kNoop
  end

  if env.add_input:len() > 0 then
    if key_event:eq(env.add_key) then
      local key = snow.key(env.add_input, env.add_word)
      local epoch = snow.epoch()
      local value = snow.format(snow.encode(epoch, env.add_index))
      env.user_dict:update(key, value)
      snow.errorf("时间戳 %d：添加新词「%s」到 %s 候选 %d", epoch, env.add_word, env.add_input, env.add_index)
      env.add_input = ""
      context:set_option("add", false)
      return snow.kAccepted
    elseif key_event.keycode == snow.kEscape then
      env.add_input = ""
      snow.errorf("取消添加新词")
      context:set_option("add", false)
      return snow.kAccepted
    end
    return snow.kNoop -- 正在添加新词，忽略其他按键
  end
  -- 前摇过长
  local segment = context.composition:toSegmentation():back()
  local input = snow.current(context)
  if not segment or not input then
    return snow.kNoop
  end
  local shape_input = context:get_property("shape_input")
  if shape_input then
    input = input .. shape_input
  end
  local candidate = context:get_selected_candidate()
  local index = segment.selected_index + 1
  if not candidate then
    return snow.kNoop
  end
  local word = candidate.text
  local key = snow.key(input, word)
  local epoch = snow.epoch()

  if key_event:eq(env.fix_key) then -- 固定/取消固定
    local value = snow.format(snow.encode(epoch, index))
    if this.is_fixed(candidate) then
      local found = false
      local entries = env.dict[input] or {}
      for _, entry in ipairs(entries) do
        if entry == word then
          found = true
          break
        end
      end
      local special_index = found and 0 or snow.DISABLE_INDEX
      value = snow.format(snow.encode(epoch, special_index))
      snow.errorf("时间戳 %d：「%s」取消 %s 候选 %d", epoch, word, input, index)
    else
      snow.errorf("时间戳 %d：「%s」固定 %s 候选 %d", epoch, word, input, index)
    end
    env.user_dict:update(key, value)
    this.refresh_recover(context, index)
    return snow.kAccepted
  elseif key_event:eq(env.add_key) then -- 添加新词
    local add_index = this.get_first_available_index(env)
    if not add_index then
      snow.errorf("无法添加新词：%s 候选已满", input)
      return snow.kAccepted
    end
    env.add_word = ""
    env.add_input = input
    env.add_index = add_index
    context:clear()
    context:set_option("add", true)
    snow.errorf("准备添加新词")
    return snow.kAccepted
  elseif key_event:eq(env.up_key) then
    if not this.is_fixed(candidate) or index <= 1 then
      return snow.kNoop
    end
    local value = snow.format(snow.encode(epoch, index - 1))
    snow.errorf("时间戳 %d：「%s」在 %s 候选 %d → %d", epoch, word, input, index, index - 1)
    this.check_move(input, index - 1, index, env)
    env.user_dict:update(key, value)
    this.refresh_recover(context, index - 1)
    return snow.kAccepted
  elseif key_event:eq(env.down_key) then
    if not this.is_fixed(candidate) or index >= snow.MAX_INDEX then
      return snow.kNoop
    end
    local value = snow.format(snow.encode(epoch, index + 1))
    snow.errorf("时间戳 %d：「%s」在 %s 候选 %d → %d", epoch, word, input, index, index + 1)
    this.check_move(input, index + 1, index, env)
    env.user_dict:update(key, value)
    this.refresh_recover(context, index + 1)
    return snow.kAccepted
  elseif key_event:eq(env.reset_key) then
    local da = env.user_dict:query(input .. snow.separator)
    for k, v in da:iter() do
      local _, existing_index = snow.decode(snow.parse(v) or 0)
      if existing_index ~= snow.DISABLE_INDEX then
        env.user_dict:update(k, snow.format(snow.encode(epoch, snow.DISABLE_INDEX)))
      end
    end
    ---@diagnostic disable-next-line: cast-local-type
    da = nil
    collectgarbage()
    snow.errorf("时间戳 %d：重置在 %s 的候选", epoch, input)
    this.refresh_recover(context, index)
    return snow.kAccepted
  end
  return snow.kNoop
end

---@param env UserDbEnv
function this.fini(env)
  env.dict = nil
  if env.user_dict then
    env.user_dict = nil
    snow.release_db(env.engine.schema.schema_id)
  end
  if env.connection then
    env.connection:disconnect()
  end
end

return this

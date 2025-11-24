-- 回头补码处理器

local snow = require "snow.snow"

local this = {}

---@class EditorEnv: Env
---@field match string
---@field accept string

---@param env EditorEnv
function this.init(env)
  local config = env.engine.schema.config
  local editor_config = config:get_map("speller/editor")
  if editor_config then
    env.match = editor_config:get_value("match"):get_string() or ""
    env.accept = editor_config:get_value("accept"):get_string() or ""
  end
end

---@param key_event KeyEvent
---@param env EditorEnv
function this.func(key_event, env)
  local context = env.engine.context
  -- 只对无修饰按键生效
  if key_event:ctrl() or key_event:alt() or key_event:super() or key_event:release() then
    return snow.kNoop
  end
  local incoming = utf8.char(key_event.keycode)
  local incoming_repr = key_event:repr()
  -- 只在顶功模式下生效
  if not context:get_option("popping") then
    return snow.kNoop
  end
  -- 只对 aeiou 和 Backspace 键生效
  -- 如果输入是 aeiou，则添加一个码
  -- 如果输入是 Backspace，则从之前增加的补码中删除一个码
  if not (rime_api.regex_match(incoming, env.accept) or incoming_repr == "BackSpace") then
    return snow.kNoop
  end
  -- 判断是否满足补码条件：末音节有 3 码，且前面至少还有一个音节
  -- confirmed_position 是拼音整句中已经被确认的编码的长度，只有后面的部分是可编辑的
  -- current_input 获取的是这部分的编码
  -- 这样，我们就可以在拼音整句中多次应用补码，而不会影响到已经确认的部分
  local confirmed_position = context.composition:toSegmentation():get_confirmed_position()
  local previous_caret_pos = context.caret_pos
  local current_input = context.input:sub(confirmed_position + 1, previous_caret_pos)
  if not rime_api.regex_match(current_input, env.match) then
    return snow.kNoop
  end
  -- 如果输入是 BackSpace，还要验证是否有补码
  if incoming_repr == "BackSpace" then
    if not rime_api.regex_match(current_input, "[bpmfdtnlgkhjqxzcsrywv][aeiou;,./]+.+") then
      return snow.kNoop
    end
  end
  -- 找出补码的位置（第二个音节之前），并添加补码
  local first_char_code_len = current_input:find("[bpmfdtnlgkhjqxzcsrywv]", 2) - 1
  context.caret_pos = confirmed_position + first_char_code_len
  if incoming_repr == "BackSpace" then
    context:pop_input(1)
    first_char_code_len = first_char_code_len - 1
  else
    context:push_input(incoming)
    first_char_code_len = first_char_code_len + 1
  end
  -- 如果补码后不到 4 码，则返回当前的位置，使得补码后的输入可以继续匹配词语；
  -- 如果补码后已有 4 码，则不返回，相当于进入单字模式
  if first_char_code_len < 4 then
    context.caret_pos = previous_caret_pos + 1
  end
  return snow.kAccepted
end

return this

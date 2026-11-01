-- 缓冲开关翻译器
-- 选择命令候选后清除命令编码并切换缓冲，不上屏候选文字

---@class BufferedEnv: Env
---@field selected boolean
---@field prepare_connection Connection
---@field select_connection Connection

local translator = {}

---@param env BufferedEnv
function translator.init(env)
  env.selected = false
  local context = env.engine.context
  -- 先于引擎的 OnSelect 禁用自动上屏；此时不能清空 composition，OnSelect 还要访问当前段。
  env.prepare_connection = context.select_notifier:connect(function(ctx)
    local candidate = ctx:get_selected_candidate()
    env.selected = candidate ~= nil and candidate:get_genuine().type == "buffered"
    if env.selected then
      ctx:set_option("_auto_commit", false)
    end
  end, 0)
  -- 等引擎处理完选择后再清空命令，buffered 的联动由顶功处理器负责。
  env.select_connection = context.select_notifier:connect(function(ctx)
    if env.selected then
      env.selected = false
      local buffered = not ctx:get_option("buffered")
      ctx:clear()
      ctx:set_option("buffered", buffered)
    end
  end)
end

---@param input string
---@param segment Segment
---@param env BufferedEnv
function translator.func(input, segment, env)
  if input == "o" and segment.start == 0 and env.engine.context.input == "o" then
    local text = env.engine.context:get_option("buffered") and "📝 关闭缓冲" or "📝 开启缓冲"
    yield(Candidate("buffered", segment.start, segment._end, text, ""))
  end
end

---@param env BufferedEnv
function translator.fini(env)
  env.prepare_connection:disconnect()
  env.select_connection:disconnect()
end

return translator

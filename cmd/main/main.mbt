///|
/// MoonEco MCP 的 STDIO 事件循环。
///
/// 协议：MCP 的 STDIO 传输使用**换行分隔的 JSON**（每条消息一行）。
/// 因此这里逐行读取、逐行写回。
///
/// 两条必须遵守的约定：
/// 1. **stdout 只写协议消息** —— 任何日志都必须走 stderr，
///    否则会污染协议流让客户端解析失败。
/// 2. **通知不回应** —— `dispatch` 返回 `NoResponse` 时不得写出任何内容。
///
/// 注意 MoonBit 的异步模型：调用 `async fn` **不需要 await**，直接调用即可。
///
/// 用法：
///   moon run cmd/main            # 本地运行（从 stdin 读协议消息）
///   moon build --target native   # 产出可执行文件
async fn main {
  while true {
    let line = @stdio.stdin.read_until("\n")
    match line {
      // stdin 关闭 = 客户端退出，事件循环随之结束。
      None => break
      Some(text) =>
        // 空行直接跳过，避免把心跳/空行当成协议消息。
        if text.trim().length() > 0 {
          match handle(text) {
            None => ()
            Some(response) => {
              // String 实现了 `Data`，可直接交给 Writer；
              // 逐条写出而不是攒批，保证客户端及时拿到响应。
              @stdio.stdout.write(response)
              @stdio.stdout.write("\n")
            }
          }
        }
    }
  }
}

///|
/// 协议决定 + 工具执行。
///
/// 纯协议部分交给 `@mcp.dispatch`（可在任意后端测试）；
/// 只有需要 I/O 的工具调用才在这里执行。
async fn handle(text : StringView) -> String? {
  match @mcp.dispatch(text) {
    Respond(json) => Some(json)
    NoResponse => None
    CallTool(id, name, args) => Some(execute_tool(id, name, args))
  }
}

///|
/// 执行一个工具。
///
/// 失败一律通过 **`isError: true` 的工具结果**返回，而不是 JSON-RPC 错误：
/// 这样模型能看到失败原因并自己换个策略，而不是收到一个它无法处理的协议错误。
async fn execute_tool(id : Json, name : String, args : Json?) -> String {
  match name {
    "search_packages" => {
      let intent = match @mcp.arg_string(args, "intent") {
        Some(s) =>
          if s.trim().length() == 0 {
            return @mcp.tool_result(
              id,
              "The 'intent' argument must not be empty.",
              is_error=true,
            )
          } else {
            s
          }
        None =>
          return @mcp.tool_result(
            id,
            "Missing required argument: intent",
            is_error=true,
          )
      }
      let limit = match @mcp.arg_int(args, "limit") {
        Some(n) => if n <= 0 { 10 } else { n }
        None => 10
      }
      // 关键：区分「上游不可达」与「没有匹配结果」。
      // 两者对模型的含义完全不同 —— 前者应重试或换用缓存，后者应换关键词。
      match @net.fetch_search(intent, limit) {
        None =>
          @mcp.tool_result(
            id,
            "Could not reach mooncakes.io. Check network connectivity, then retry.",
            is_error=true,
          )
        Some(hits) => {
          let ranked = @rank.rank(hits, intent)
          @mcp.tool_result(
            id,
            @mcp.render_search_results(intent, ranked),
            is_error=false,
          )
        }
      }
    }
    _ =>
      @mcp.tool_result(id, "Tool not implemented yet: " + name, is_error=true)
  }
}

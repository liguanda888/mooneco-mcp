///|
/// MoonEco MCP 的 STDIO 事件循环。
///
/// 协议：MCP 的 STDIO 传输使用**换行分隔的 JSON**（每条消息一行）。
/// 因此这里逐行读取、逐行写回。
///
/// 两条必须遵守的约定：
/// 1. **stdout 只写协议消息** —— 任何日志都必须走 stderr，
///    否则会污染协议流让客户端解析失败。
/// 2. **通知不回应** —— `handle_message` 返回 `None` 时不得写出任何内容。
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
          match @mcp.handle_message(text) {
            // 通知（无 id）：按规范不得回应。
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

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
    "search_packages" => execute_search_packages(id, args)
    "get_package_api" => execute_get_package_api(id, args)
    _ =>
      @mcp.tool_result(id, "Tool not implemented yet: " + name, is_error=true)
  }
}

///|
/// `search_packages`：按意图检索生态包。
async fn execute_search_packages(id : Json, args : Json?) -> String {
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
    None => @mcp.tool_result(id, upstream_unreachable, is_error=true)
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

///|
/// `get_package_api`：取单个包的真实事实（依赖表、版本历史、构建状态等）。
///
/// 注意工具名里的 "api" 是历史命名。**上游并不提供函数签名**，
/// 因此本工具不会编造 API 摘要，而是如实给出能核实的信息，
/// 并指向仓库 README 让模型去读权威来源。
async fn execute_get_package_api(id : Json, args : Json?) -> String {
  let name = match @mcp.arg_string(args, "name") {
    Some(s) =>
      if s.trim().length() == 0 {
        return @mcp.tool_result(
          id,
          "The 'name' argument must not be empty.",
          is_error=true,
        )
      } else {
        s
      }
    None =>
      return @mcp.tool_result(
        id,
        "Missing required argument: name (expected owner/pkg, for example mizchi/parquet)",
        is_error=true,
      )
  }
  match @net.fetch_module_raw(name) {
    None => @mcp.tool_result(id, upstream_unreachable_for(name), is_error=true)
    Some(raw) =>
      match @mooncakes.decode_module(raw) {
        None =>
          @mcp.tool_result(
            id,
            "Unexpected response from mooncakes.io for '" +
            name +
            "'. Check that the package name is in owner/pkg form.",
            is_error=true,
          )
        Some(detail) =>
          @mcp.tool_result(
            id,
            @mcp.render_package_detail(detail),
            is_error=false,
          )
      }
  }
}

///|
/// 上游不可达时的统一提示 —— 对模型最重要的是"这是网络问题，可以重试"。
let upstream_unreachable : String = "Could not reach mooncakes.io. Check network connectivity, then retry."

///|
/// 针对某个包名定制的不可达提示。
fn upstream_unreachable_for(name : String) -> String {
  "Could not reach mooncakes.io for '" +
  name +
  "'. Check network connectivity, then retry."
}

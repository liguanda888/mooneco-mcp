///|
/// MCP 方法分发：把一条入站消息变成一条出站消息。
///
/// 本文件是**纯逻辑**——不读 stdin、不写 stdout。
/// 真正的 STDIO 事件循环在 `cmd/main`，这样可以脱离进程测试协议行为。

///|
/// 处理一条入站消息。
///
/// 返回值的语义：
/// - `Some(json)` —— 需要回应，写出这条 JSON
/// - `None` —— **不应回应**（通知，按规范不得回复）
pub fn handle_message(text : StringView) -> String? {
  let request = match parse_request(text) {
    Some(r) => r
    None =>
      // 解析失败也要回应；此时拿不到 id，按规范用 null。
      return Some(error_response(Json::null(), parse_error_code, "Parse error"))
  }
  let id = match request.id {
    Some(i) => i
    // 通知（无 id）：MCP 的 `notifications/initialized` 就走这条路径。
    None => return None
  }
  match request.method_name {
    "initialize" => Some(success_response(id, initialize_result()))
    "tools/list" => Some(success_response(id, tools_list_result))
    "ping" => Some(success_response(id, "{}"))
    "tools/call" => Some(handle_tools_call(id, request.params))
    _ =>
      Some(
        error_response(
          id,
          method_not_found_code,
          "Method not found: " + request.method_name,
        ),
      )
  }
}

///|
/// 处理 `tools/call`。
///
/// 当前为骨架：校验入参并回一个明确的"尚未实现"错误。
/// 这样客户端拿到的是**可解释的协议级错误**，而不是超时或崩溃；
/// 具体实现在 M3/M4 里程碑替换本函数。
pub fn handle_tools_call(id : Json, params : Json?) -> String {
  let name = match params {
    Some(Object(p)) =>
      match p.get("name") {
        Some(String(n)) => n
        _ => ""
      }
    _ => ""
  }
  if name == "" {
    return error_response(id, invalid_params_code, "Missing tool name")
  }
  error_response(id, method_not_found_code, "Tool not implemented yet: " + name)
}

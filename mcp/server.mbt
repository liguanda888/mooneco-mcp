///|
/// MCP 方法分发：把一条入站消息变成"该做什么"。
///
/// 本文件是**纯逻辑**——不读 stdin、不写 stdout、不联网。
///
/// 关键设计：`tools/call` 需要执行 I/O（联网检索生态），而协议层必须保持纯，
/// 才能在任意后端、无进程、无网络的情况下被测试。因此这里不直接执行工具，
/// 而是把"需要执行哪个工具"作为 `Outcome::CallTool` 交给上层。
/// 这样**协议决定**与**I/O 执行**各自独立可测。

///|
/// 分发的三种结局。
///
/// MoonBit 的枚举变体用**位置类型**携带数据（与 `Json::Number(Double, ..)` 一致），
/// 因此这里不写字段名，语义靠顺序与文档约定。
pub(all) enum Outcome {
  /// 需要回应这条 JSON。
  Respond(String)
  /// 不应回应（通知，按 JSON-RPC 规范不得回复）。
  NoResponse
  /// 需要执行工具（id, name, arguments）；待上层执行后自行构造响应。
  CallTool(Json, String, Json?)
} derive(Debug)

///|
/// 处理一条入站消息，返回该做什么。
pub fn dispatch(text : StringView) -> Outcome {
  let request = match parse_request(text) {
    Some(r) => r
    None =>
      // 解析失败也要回应；此时拿不到 id，按规范用 null。
      return Respond(
        error_response(Json::null(), parse_error_code, "Parse error"),
      )
  }
  let id = match request.id {
    Some(i) => i
    // 通知（无 id）：MCP 的 `notifications/initialized` 就走这条路径。
    None => return NoResponse
  }
  match request.method_name {
    "initialize" => Respond(success_response(id, initialize_result()))
    "tools/list" => Respond(success_response(id, tools_list_result))
    "ping" => Respond(success_response(id, "{}"))
    "tools/call" =>
      match tool_name(request.params) {
        Some(name) => CallTool(id, name, tool_arguments(request.params))
        None =>
          Respond(error_response(id, invalid_params_code, "Missing tool name"))
      }
    _ =>
      Respond(
        error_response(
          id,
          method_not_found_code,
          "Method not found: " + request.method_name,
        ),
      )
  }
}

///|
/// 从 `tools/call` 的 params 里取工具名。
/// 入参形状：`{"name":"search_packages","arguments":{...}}`
pub fn tool_name(params : Json?) -> String? {
  match params {
    Some(Object(p)) =>
      match p.get("name") {
        Some(String(n)) => Some(n)
        _ => None
      }
    _ => None
  }
}

///|
/// 从 `tools/call` 的 params 里取 `arguments` 对象。
pub fn tool_arguments(params : Json?) -> Json? {
  match params {
    Some(Object(p)) => p.get("arguments")
    _ => None
  }
}

///|
/// 从工具入参里取字符串字段。
pub fn arg_string(args : Json?, key : String) -> String? {
  match args {
    Some(Object(m)) =>
      match m.get(key) {
        Some(String(s)) => Some(s)
        _ => None
      }
    _ => None
  }
}

///|
/// 从工具入参里取整数字段。JSON 数字统一是 Double，这里截断为 Int。
pub fn arg_int(args : Json?, key : String) -> Int? {
  match args {
    Some(Object(m)) =>
      match m.get(key) {
        Some(Number(n, ..)) => Some(n.to_int())
        _ => None
      }
    _ => None
  }
}

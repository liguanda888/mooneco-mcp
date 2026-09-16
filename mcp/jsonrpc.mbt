///|
/// JSON-RPC 2.0 消息的解析与构造。
///
/// 只实现 MCP 实际用到的子集：请求（含通知）与响应。
/// 取舍：**宽容解析、严格输出**——入站消息缺字段时降级处理而不是崩溃，
/// 出站消息则严格按规范拼装。

///|
/// 一条 JSON-RPC 请求（或通知）。
///
/// `id` 为 `None` 表示通知：按规范**不应**回应。
/// 注意 `id` 在 JSON-RPC 里可以是字符串或数字，所以用 `Json` 原样保存。
///
/// 字段名用 `method_name` 而非 `method`：`method` 是 MoonBit 的保留字。
pub(all) struct RpcRequest {
  method_name : String
  id : Json?
  params : Json?
} derive(Debug)

///|
/// 解析一条 JSON-RPC 请求。返回 `None` 表示输入不是合法请求
/// （非法 JSON、缺少 `method`、或 `jsonrpc` 字段不是 "2.0"）。
pub fn parse_request(text : StringView) -> RpcRequest? {
  let root = @json.parse(text) catch { _ => return None }
  guard root is Object(obj) else { return None }
  // 规范要求 jsonrpc 字段为 "2.0"；缺失或不等都判为非法请求。
  match obj.get("jsonrpc") {
    Some(String(v)) => if v != "2.0" { return None }
    _ => return None
  }
  let method_name = match obj.get("method") {
    Some(String(m)) => m
    _ => return None
  }
  let id = obj.get("id")
  let params = obj.get("params")
  Some({ method_name, id, params, })
}

///|
/// 构造成功响应。`result_json` 是**已经序列化好的** JSON 片段。
///
/// 为什么让调用方传字符串：本项目的响应体是静态目录数据（工具清单、
/// 初始化信息），以 JSON 字面量维护更直观，也更容易被测试逐字校验。
/// 而 `id` 交给 `Json::stringify` 处理，避免自己实现字符串转义。
pub fn success_response(id : Json, result_json : String) -> String {
  "{\"jsonrpc\":\"2.0\",\"id\":" +
  id.stringify() +
  ",\"result\":" +
  result_json +
  "}"
}

///|
/// 构造错误响应。
pub fn error_response(id : Json, code : Int, message : String) -> String {
  "{\"jsonrpc\":\"2.0\",\"id\":" +
  id.stringify() +
  ",\"error\":{\"code\":" +
  code.to_string() +
  ",\"message\":" +
  @json.to_json(message).stringify() +
  "}}"
}

///|
/// JSON-RPC 标准错误码。
pub let parse_error_code : Int = -32700

///|
pub let invalid_request_code : Int = -32600

///|
pub let method_not_found_code : Int = -32601

///|
pub let invalid_params_code : Int = -32602

///|
/// MoonEco MCP 模块根包。
///
/// 目标：让 AI 编程代理真正读懂 MoonBit 生态 —— 既知道生态里有什么包、
/// 它们的 API 长什么样，也能在 token 预算内拿到「理解 MoonBit 语义」的项目上下文。
///
/// 子包：
/// - `mooncakes/` —— mooncakes.io API 客户端与本地快照缓存
/// - `rank/`      —— 检索结果的相关性打分与排序
/// - `context/`   —— MoonBit 语义级上下文打包（token 预算切分）
/// - `mcp/`       —— MCP 协议层（JSON-RPC 2.0 over STDIO）

///|
/// 项目版本号，与 `moon.mod` 保持一致。
pub let version : String = "0.1.0"

///|
/// 一句话描述，供 CLI 与 MCP 的 `serverInfo` 使用。
pub fn describe() -> String {
  "MoonEco MCP v" +
  version +
  " — MoonBit ecosystem knowledge and MoonBit-semantic context packing for AI agents"
}

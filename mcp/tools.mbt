///|
/// MCP 的工具清单与初始化信息。
///
/// 这里的 `description` 与 `inputSchema` **一律用英文** ——
/// 它们由模型消费，英文的调用准确率更好（见 AGENTS.md 的约定）。
/// 说明性注释则保持中文，便于评审阅读。

///|
/// 我们实现的 MCP 协议版本。
pub let protocol_version : String = "2024-11-05"

///|
/// `initialize` 的 result。
/// `serverInfo.version` 直接取自模块根包的版本号，避免两处维护。
pub fn initialize_result() -> String {
  "{\"protocolVersion\":\"" +
  protocol_version +
  "\",\"capabilities\":{\"tools\":{}},\"serverInfo\":{\"name\":\"mooneco-mcp\",\"version\":\"" +
  @mooneco.version +
  "\"}}"
}

///|
/// `tools/list` 的 result：四个工具的清单。
///
/// 以 JSON 字面量维护 —— 它是静态数据，这样每个工具的英文描述与
/// 入参 schema 都一目了然。测试会解析这段字面量，确保它始终是
/// 合法 JSON 且四个工具齐全。
pub let tools_list_result : String = "{\"tools\":[" +
  "{\"name\":\"search_packages\"," +
  "\"description\":\"Search MoonBit ecosystem packages on mooncakes.io by intent. Call this before writing code that may already exist as a package. Returns package name, version, license, download count and publish date, ranked by name/keyword/description match plus download count.\"," +
  "\"inputSchema\":{\"type\":\"object\",\"properties\":{\"intent\":{\"type\":\"string\",\"description\":\"Natural-language description of what you want to do\"},\"limit\":{\"type\":\"integer\",\"description\":\"Maximum number of results, default 10\"}},\"required\":[\"intent\"]}}," +
  "{\"name\":\"get_package_api\"," +
  "\"description\":\"Get verifiable facts about a MoonBit package: its dependency table, version history, license, build status and repository, read straight from mooncakes.io. Note that mooncakes.io exposes no function signatures, so read the repository README for the API surface; this tool will not guess it.\"," +
  "\"inputSchema\":{\"type\":\"object\",\"properties\":{\"name\":{\"type\":\"string\",\"description\":\"Package name in owner/pkg form, for example mizchi/parquet\"},\"version\":{\"type\":\"string\",\"description\":\"Package version; defaults to the latest\"}},\"required\":[\"name\"]}}," +
  "{\"name\":\"suggest_dependencies\"," +
  "\"description\":\"Given a requirement in natural language, return which MoonBit packages to use, with alternatives compared by download count, license and publish date.\"," +
  "\"inputSchema\":{\"type\":\"object\",\"properties\":{\"requirement\":{\"type\":\"string\",\"description\":\"What you want to build, in natural language\"}},\"required\":[\"requirement\"]}}," +
  "{\"name\":\"pack_project_context\"," +
  "\"description\":\"Pack the relevant parts of a MoonBit project into a token budget, ranked by import relevance, and attach the verifiable dependency and version facts of the packages the project uses.\"," +
  "\"inputSchema\":{\"type\":\"object\",\"properties\":{\"path\":{\"type\":\"string\",\"description\":\"Path to the MoonBit project root\"},\"budget\":{\"type\":\"integer\",\"description\":\"Token budget for the packed context\"}},\"required\":[\"path\",\"budget\"]}}" +
  "]}"

///|
/// 四个工具的名字，供测试与后续实现引用。
pub let tool_names : Array[String] = [
  "search_packages", "get_package_api", "suggest_dependencies", "pack_project_context",
]

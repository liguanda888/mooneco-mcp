///|
/// mooncakes.io API 客户端（native 传输层）。
///
/// 设计取舍：所有网络失败都**降级为空结果**，而不是向上抛异常。
/// 理由有两条：
/// 1. MCP 工具的一次检索失败不应该让整个会话崩溃；
/// 2. 对调用方来说「上游不可达」与「没有匹配结果」的处置方式一致
///    —— 都应该退回本地快照缓存，而不是中断。
///
/// 也正因为如此，本层的失败路径是**可测的**：不触网时返回空数组。

///|
/// 按关键词检索生态包。
///
/// 对应 `GET /api-new/v0/search?kw=<关键词>&limit=<n>`。
/// 网络或解析失败时返回空数组。
pub async fn fetch_search(
  keyword : StringView,
  limit : Int,
) -> Array[@mooncakes.PackageHit] {
  let text = try {
    let (_response, body) = @http.get(search_url(keyword, limit))
    body.text()
  } catch {
    _ => return []
  }
  @mooncakes.decode_search(text)
}

///|
/// 取单个包的详情响应原文。
///
/// 对应 `GET /api-new/v0/modules/<owner>/<name>`。
/// 此处只负责取回原文，字段解析留给后续里程碑 —— 避免在还没有
/// `get_package_api` 工具需求时过早抽象出中间结构。
/// 失败时返回空串。
pub async fn fetch_module_raw(name : StringView) -> String {
  try {
    let (_response, body) = @http.get(module_url(name))
    body.text()
  } catch {
    _ => ""
  }
}

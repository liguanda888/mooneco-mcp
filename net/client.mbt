///|
/// mooncakes.io API 客户端（native 传输层）。
///
/// 设计取舍：网络失败**不向上抛异常**，而是返回 `None`。
/// 理由：MCP 工具的一次检索失败不应该让整个会话崩溃。
///
/// 但**不能把失败和"无结果"都退回空数组** —— 这两件事对模型的含义完全不同：
/// 前者应当重试或退回缓存，后者应当换关键词。合并会让模型误判为
/// "生态里没有这个包"，从而放弃一个其实存在的方案。

///|
/// 按关键词检索生态包。
///
/// 对应 `GET /api-new/v0/search?kw=<关键词>&limit=<n>`。
///
/// - 返回 `None`：请求失败（网络不可达、或响应不是合法 JSON）
/// - 返回 `Some([])`：请求成功，但没有匹配结果
pub async fn fetch_search(
  keyword : StringView,
  limit : Int,
) -> Array[@mooncakes.PackageHit]? {
  let text = try {
    let (_response, body) = @http.get(search_url(keyword, limit))
    body.text()
  } catch {
    _ => return None
  }
  // 上游出错时往往返回 HTML 或空响应；用"是否是合法 JSON"
  // 作为请求是否真正成功的判据，避免把错误页当成零结果。
  if !@json.valid(text) {
    return None
  }
  Some(@mooncakes.decode_search(text))
}

///|
/// 取单个包的详情响应原文。
///
/// 对应 `GET /api-new/v0/modules/<owner>/<name>`。
/// 此处只负责取回原文，字段解析留给实现 `get_package_api` 的里程碑 ——
/// 避免在还没有该工具需求时过早抽象出中间结构。
/// 失败（网络错误或响应非合法 JSON）时返回 `None`。
pub async fn fetch_module_raw(name : StringView) -> String? {
  try {
    let (_response, body) = @http.get(module_url(name))
    let text = body.text()
    if @json.valid(text) {
      Some(text)
    } else {
      None
    }
  } catch {
    _ => None
  }
}

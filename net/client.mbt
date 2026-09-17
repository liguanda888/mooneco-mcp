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

///|
/// 从包仓库取 README 正文。
///
/// 为什么需要这一步：mooncakes.io 的 API **不提供** README 正文
/// （`metadata.readme` 只是文件名），也不提供函数签名。
/// 而 MoonBit 包的 API 用法恰恰写在 README 里 —— 所以要让 AI 不猜 API，
/// 就得把 README 交到它手上。
///
/// 取的是 GitHub 的 raw 地址（纯文本，不是抓 HTML 页面）。
/// 逐个尝试 `readme_url_candidates` 给出的地址：
/// `main` / `master` 两种默认分支 × `README.md` / `README.mbt.md` 两种文件名。
///
/// 返回 `None` 表示**没有拿到**（仓库不在 GitHub、地址形式不认识、或都 404）——
/// 这不是错误，上层会降级成"只给事实、不给 README"。
pub async fn fetch_readme(repository : StringView) -> String? {
  let (owner, repo) = match github_owner_repo(repository) {
    Some(pair) => pair
    None => return None
  }
  for url in readme_url_candidates(owner, repo) {
    let fetched : String? = try {
      let (_response, body) = @http.get(url)
      Some(body.text())
    } catch {
      _ => None
    }
    match fetched {
      // 空文件视为没取到，继续尝试下一个候选地址。
      Some(text) => if text.trim().length() > 0 { return Some(text) }
      None => ()
    }
  }
  None
}

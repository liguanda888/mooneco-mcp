///|
/// mooncakes.io / GitHub 的客户端（native 传输层）。
///
/// 设计取舍：网络失败**不向上抛异常**，而是返回 `None`。
/// 理由：MCP 工具的一次检索失败不应该让整个会话崩溃。
///
/// 但**不能把失败和"无结果"都退回空数组** —— 这两件事对模型的含义完全不同：
/// 前者应当重试或退回缓存，后者应当换关键词。合并会让模型误判为
/// "生态里没有这个包"，从而放弃一个其实存在的方案。

///|
/// 单次 HTTP 尝试的超时（毫秒）。
///
/// 为什么必须有它：`raw.githubusercontent.com` 在中国大陆网络下的失败方式
/// **不是**返回 404，而是 TCP 连接被丢弃、长时间没有响应。没有超时的话，
/// 一次工具调用会**永久挂住** —— 那比"取不到 README"糟糕得多，
/// 因为调用方连降级的机会都没有。
///
/// 8 秒的取舍：实测 `api.github.com` 约 7 秒、`cdn.jsdelivr.net` 约 2 秒。
/// 留够慢链路的余量，又不至于让一次多源尝试拖到不可接受。
let http_attempt_timeout_ms : Int = 8000

///|
/// 取一个 URL 的正文。
///
/// 下列情况一律算失败并返回 `None`：
///   - 超时（含连接被丢弃）
///   - 抛异常（DNS、TLS 等）
///   - **非 2xx**（尤其 3xx 跳转：jsDelivr 冷缓存时会先回一个 301，
///     拿到跳转页当 README 比取不到更糟）
///   - 正文为空或只有空白
async fn get_text(url : String) -> String? {
  let fetched : String? = @async.with_timeout_opt(http_attempt_timeout_ms) <| () => {
    try {
      let (response, body) = @http.get(url)
      if response.code >= 200 && response.code < 300 {
        body.text()
      } else {
        ""
      }
    } catch {
      _ => ""
    }
  }
  match fetched {
    Some(text) => if text.trim().length() > 0 { Some(text) } else { None }
    None => None
  }
}

///|
/// 按关键词检索生态包。
///
/// 对应 `GET /api-new/v0/search?kw=<关键词>&limit=<n>`。
///
/// - 返回 `None`：请求失败（网络不可达、超时、或响应不是合法 JSON）
/// - 返回 `Some([])`：请求成功，但没有匹配结果
pub async fn fetch_search(
  keyword : StringView,
  limit : Int,
) -> Array[@mooncakes.PackageHit]? {
  let text = match get_text(search_url(keyword, limit)) {
    Some(t) => t
    None => return None
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
/// 失败（网络错误、超时，或响应不是合法 JSON）时返回 `None`。
pub async fn fetch_module_raw(name : StringView) -> String? {
  let text = match get_text(module_url(name)) {
    Some(t) => t
    None => return None
  }
  if @json.valid(text) {
    Some(text)
  } else {
    None
  }
}

///|
/// 从 GitHub 官方 README 接口取正文。
///
/// 响应形如：
///   `{"name":"README.md","content":"<base64>","encoding":"base64", ...}`
/// 需要 base64 解码，再按 UTF-8 读成字符串。
///
/// 任一环节不成立都返回 `None`（而不是抛异常），由上层继续尝试其它源。
async fn fetch_github_readme(owner : String, repo : String) -> String? {
  let raw = match get_text(github_readme_api_url(owner, repo)) {
    Some(t) => t
    None => return None
  }
  let parsed = @json.parse(raw) catch { _ => return None }
  guard parsed is Object(obj) else { return None }
  let encoded = match obj.get("content") {
    Some(String(s)) => s
    _ => return None
  }
  // GitHub 返回的 base64 带换行，必须忽略空白字符。
  let bytes = @base64.decode(encoded, ignore_whitespace=true) catch {
    _ => return None
  }
  let text = @utf8.decode(bytes) catch { _ => return None }
  if text.trim().length() > 0 {
    Some(text)
  } else {
    None
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
/// 多源策略（按顺序，第一个成功即返回）：
///   1. `api.github.com` 官方接口 —— 一次请求拿到默认分支的 README，不用猜分支
///   2. `readme_url_candidates` —— jsDelivr 镜像与 raw 备选，覆盖国内外不同网络
///
/// 返回 `None` 表示**没有拿到**（仓库不在 GitHub、地址形式不认识、都超时或 404）——
/// 这不是错误，上层会降级成"只给事实、不给 README"。
pub async fn fetch_readme(repository : StringView) -> String? {
  let (owner, repo) = match github_owner_repo(repository) {
    Some(pair) => pair
    None => return None
  }
  match fetch_github_readme(owner, repo) {
    Some(text) => return Some(text)
    None => ()
  }
  for url in readme_url_candidates(owner, repo) {
    match get_text(url) {
      Some(text) => return Some(text)
      None => ()
    }
  }
  None
}

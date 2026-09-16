///|
/// 相关性打分与排序。
///
/// 设计原则：
/// 1. **只用真实存在的字段**——名称、关键词、描述、下载量、`is_new`。
/// 2. **可解释**——每一档权重都是常量，评审能一条条核对。
/// 3. **稳定**——同分时有确定的次序，不依赖排序算法的内部行为。

///|
/// 对单个检索结果打分，分数越高越相关；0 表示与查询无关。
///
/// 权重设计（从高到低）：
/// - 名称完全匹配        +1000
/// - 包名段完全匹配      +600   （如查询 `parquet` 命中 `mizchi/parquet`）
/// - 名称包含            +300
/// - 每个关键词完全匹配  +150
/// - 描述包含            +50
/// - 下载量              +10 × 十进制位数（**仅对相关结果**）
/// - 新包               +20（**仅对相关结果**）
///
/// 关键取舍：**没有任何文本相关信号时直接返回 0**，不再叠加下载量与
/// 新包加成。否则一个下载量极高的无关包会仅凭"下载量分"混进结果 ——
/// 下载量与新包应当是**相关结果之间的区分度**，而不是相关性的来源。
/// （这一点由单元测试发现。）
pub fn score(hit : @mooncakes.PackageHit, query : StringView) -> Int {
  let q = ascii_lower(query)
  if q.length() == 0 {
    return 0
  }
  let name = ascii_lower(hit.name)
  let mut relevance = 0
  if name == q {
    relevance = relevance + 1000
  } else if package_leaf(name) == q {
    relevance = relevance + 600
  } else if name.contains(q) {
    relevance = relevance + 300
  }
  for keyword in hit.keywords {
    if ascii_lower(keyword) == q {
      relevance = relevance + 150
    }
  }
  if ascii_lower(hit.description).contains(q) {
    relevance = relevance + 50
  }
  if relevance == 0 {
    return 0
  }
  let mut total = relevance + downloads_score(hit.downloads)
  if hit.is_new {
    total = total + 20
  }
  total
}

///|
/// 过滤掉无关结果，并按 (分数降序, 下载量降序, 名称升序) 排序。
///
/// 加后两级是为了**结果稳定**：分数相同时次序唯一，
/// 测试与演示都不会出现「同样的查询两次结果顺序不同」。
pub fn rank(
  hits : Array[@mooncakes.PackageHit],
  query : StringView,
) -> Array[@mooncakes.PackageHit] {
  let scored : Array[(@mooncakes.PackageHit, Int)] = hits
    .map(fn(h) { (h, score(h, query)) })
    .filter(fn(pair) { pair.1 > 0 })
  scored.sort_by(fn(a, b) {
    if a.1 != b.1 {
      return b.1 - a.1
    }
    if a.0.downloads != b.0.downloads {
      return b.0.downloads - a.0.downloads
    }
    a.0.name.compare(b.0.name)
  })
  scored.map(fn(pair) { pair.0 })
}

///|
/// 下载量的对数缩放：用**十进制位数**近似 `log10`。
///
/// 为什么不用浮点 `log10`：位数近似是整数运算、边界清晰、易测，
/// 而且同样达到目的 —— 让 1676 次下载不会碾压 29 次下载
/// （分别贡献 30 与 10，而不是 1676 与 29）。
fn downloads_score(downloads : Int) -> Int {
  let mut d = downloads
  let mut digits = 0
  while d >= 10 {
    d = d / 10
    digits = digits + 1
  }
  digits * 10
}

///|
/// 取 `owner/pkg` 中最后一段（`pkg`）；没有 `/` 时返回原串。
/// 逐字符重建而不是用 split，是为了避开字符串切分 API 的行为差异。
pub fn package_leaf(name : StringView) -> String {
  let buf = StringBuilder::StringBuilder()
  for ch in name {
    if ch == '/' {
      buf.reset()
    } else {
      buf.write_char(ch)
    }
  }
  buf.to_string()
}

///|
/// ASCII 小写化。
///
/// 只处理 ASCII：MoonBit 包名均为 ASCII；查询里可能有中文，
/// 而中文没有大小写概念，原样保留即正确。
///
/// 用 26 个单字符字符串查表，而不是 `Char::from_int` 之类的整数转换：
/// 后者在当前版本已废弃（且"安全版"返回可选项、需要解包），
/// 查表既没有废弃 API，也不需要 unsafe。
pub fn ascii_lower(s : StringView) -> String {
  let lower : Array[String] = [
    "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p",
    "q", "r", "s", "t", "u", "v", "w", "x", "y", "z",
  ]
  let buf = StringBuilder::StringBuilder()
  for ch in s {
    if ch >= 'A' && ch <= 'Z' {
      buf.write_string(lower[ch.to_int() - 'A'.to_int()])
    } else {
      buf.write_char(ch)
    }
  }
  buf.to_string()
}

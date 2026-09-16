///|
/// mooncakes.io 的 API 端点与 URL 构造。
///
/// 本文件是**纯函数**，不触网 —— 因此 URL 构造的正确性可以离线单元测试，
/// 这是「可复现」承诺的一部分。

///|
/// 搜索 API 端点。
let search_endpoint : String = "https://mooncakes.io/api-new/v0/search"

///|
/// 包详情 API 端点的前缀。
let modules_endpoint : String = "https://mooncakes.io/api-new/v0/modules"

///|
/// 构造搜索 URL。
///
/// 例：`search_url("parquet", 10)`
///   → `https://mooncakes.io/api-new/v0/search?kw=parquet&limit=10`
pub fn search_url(keyword : StringView, limit : Int) -> String {
  search_endpoint +
  "?kw=" +
  percent_encode(keyword) +
  "&limit=" +
  limit.to_string()
}

///|
/// 构造包详情 URL。`name` 形如 `owner/pkg`，其中的 `/` 属于路径，不编码。
pub fn module_url(name : StringView) -> String {
  modules_endpoint + "/" + name.to_owned()
}

///|
/// 百分号编码（RFC 3986）。
///
/// 保留 unreserved 字符（`A-Z a-z 0-9 - _ . ~`），其余 ASCII 字符编码为 `%XX`。
/// 非 ASCII 字符按 UTF-8 原样保留 —— mooncakes.io 接受 UTF-8 查询串，
/// 且这样可以避免自己实现 UTF-8 编码器带来的风险。
pub fn percent_encode(s : StringView) -> String {
  // 用字符串查表而不是 `String[i]`：后者返回 UTF-16 码元（UInt16），
  // 不是 Char。
  let hex : Array[String] = [
    "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "A", "B", "C", "D", "E", "F",
  ]
  // 用 builtin 的 StringBuilder，而不是 @buffer.Buffer：
  // 后者的 Logger 实现按 UTF-16LE 写入，且 to_string() 也按 UTF-16 解码，
  // 会把正确的 UTF-8 字节序列读成乱码（这一点由单元测试发现）。
  let buf = StringBuilder::StringBuilder()
  for ch in s {
    if is_unreserved(ch) {
      buf.write_char(ch)
    } else if ch.to_int() < 128 {
      let code = ch.to_int()
      buf.write_string("%")
      buf.write_string(hex[code / 16])
      buf.write_string(hex[code % 16])
    } else {
      // 非 ASCII：UTF-8 直传
      buf.write_char(ch)
    }
  }
  buf.to_string()
}

///|
/// RFC 3986 的 unreserved 字符集。
fn is_unreserved(ch : Char) -> Bool {
  (ch >= 'A' && ch <= 'Z') ||
  (ch >= 'a' && ch <= 'z') ||
  (ch >= '0' && ch <= '9') ||
  ch == '-' ||
  ch == '_' ||
  ch == '.' ||
  ch == '~'
}

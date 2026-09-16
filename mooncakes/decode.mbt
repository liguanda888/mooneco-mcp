///|
/// 从 mooncakes.io 搜索 API 的 JSON 响应解析出包列表。
///
/// 输入形如：
/// ```json
/// [{"name":"mizchi/parquet","version":"0.2.1","license":"Apache-2.0",
///   "repository":"...","keywords":["moonbit","parquet"],
///   "description":"...","downloads":1676,"created_at":"..."}]
/// ```
///
/// 行为约定（对调用方是稳定的）：
/// - JSON 语法错误、或顶层不是数组 → 返回空数组，不抛异常
/// - 数组元素不是对象 → 跳过该元素，保留其余
/// - 对象内字段缺失或类型不符 → 该字段取默认值（"" / 0 / []）
///
/// 之所以选择「宽容解析」而不是「严格失败」：检索工具的可用性
/// 比字段完备性更重要，上游加字段不应让工具整体挂掉。
pub fn decode_search(json_text : StringView) -> Array[PackageHit] {
  let root = @json.parse(json_text) catch { _ => return [] }
  guard root is Array(items) else { return [] }
  items.filter_map(decode_hit)
}

///|
/// 解析单个包条目；若不是对象则返回 None（由调用方过滤掉）。
/// 注意 `else { return None }` 不可省略：非对象元素（数字/字符串/布尔/null/数组）
/// 都必须走 None 分支，而不是 panic。
fn decode_hit(item : Json) -> PackageHit? {
  guard item is Object(obj) else { return None }
  Some({
    name: field_string(obj, "name"),
    version: field_string(obj, "version"),
    license: field_string(obj, "license"),
    repository: field_string(obj, "repository"),
    description: field_string(obj, "description"),
    keywords: field_string_array(obj, "keywords"),
    downloads: field_int(obj, "downloads"),
    created_at: field_string(obj, "created_at"),
  })
}

///|
/// 取字符串字段；缺失或类型不符时返回空串。
fn field_string(obj : Map[String, Json], key : String) -> String {
  match obj.get(key) {
    Some(String(s)) => s
    _ => ""
  }
}

///|
/// 取整数字段；缺失或类型不符时返回 0。
/// JSON 数字统一是 Double，这里截断为 Int —— 下载量远小于 2^53，安全。
/// `Number(n, ..)` 中的 `..` 是必需的：核心 Json 的数字构造子带有额外的
/// 表示形式字段，这里只关心数值本身。
fn field_int(obj : Map[String, Json], key : String) -> Int {
  match obj.get(key) {
    Some(Number(n, ..)) => n.to_int()
    _ => 0
  }
}

///|
/// 取字符串数组字段；元素中非字符串的项被丢弃。
fn field_string_array(obj : Map[String, Json], key : String) -> Array[String] {
  match obj.get(key) {
    Some(Array(items)) =>
      items.filter_map(fn(x) { if x is String(s) { Some(s) } else { None } })
    _ => []
  }
}

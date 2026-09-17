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
    is_new: field_bool(obj, "is_new"),
  })
}

///|
/// 取布尔字段；缺失或类型不符时返回 false。
fn field_bool(obj : Map[String, Json], key : String) -> Bool {
  match obj.get(key) {
    Some(True) => true
    Some(False) => false
    _ => false
  }
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

///|
/// 解析**包详情**响应（`GET /api-new/v0/modules/<owner>/<name>`）。
///
/// 已实测的上游事实决定了这个函数能给出的东西：
/// - `metadata.readme` 只是**文件名**（`"README.md"`），不是正文；
/// - 不存在公开的函数签名 / API 列表端点（候选端点逐个探测全部 404）。
///
/// 所以这里如实解析能拿到的：依赖表、版本历史、构建状态、许可证、仓库地址。
/// `module` 是必有的标识字段；缺失它说明拿到的不是详情响应（例如错误页），
/// 这时返回 `None` 而不是一个各字段为空的结构。
pub fn decode_module(json_text : StringView) -> PackageDetail? {
  let root = @json.parse(json_text) catch { _ => return None }
  guard root is Object(obj) else { return None }
  let module_name = field_string(obj, "module")
  if module_name == "" {
    return None
  }
  Some({
    module_name,
    version: field_string(obj, "version"),
    latest_version: field_string(obj, "latest_version"),
    build_status: field_string(obj, "build_status"),
    yanked: field_bool(obj, "yanked"),
    license: metadata_string(obj, "license"),
    repository: metadata_string(obj, "repository"),
    description: metadata_string(obj, "description"),
    created_at: metadata_string(obj, "created_at"),
    keywords: metadata_string_array(obj, "keywords"),
    deps: metadata_deps(obj),
    versions: metadata_versions(obj),
  })
}

///|
/// 取 `metadata` 子对象。
fn metadata_object(obj : Map[String, Json]) -> Map[String, Json]? {
  match obj.get("metadata") {
    Some(Object(m)) => Some(m)
    _ => None
  }
}

///|
/// 从 `metadata` 下取字符串字段。
fn metadata_string(obj : Map[String, Json], key : String) -> String {
  match metadata_object(obj) {
    Some(m) => field_string(m, key)
    None => ""
  }
}

///|
/// 从 `metadata` 下取字符串数组字段。
fn metadata_string_array(
  obj : Map[String, Json],
  key : String,
) -> Array[String] {
  match metadata_object(obj) {
    Some(m) => field_string_array(m, key)
    None => []
  }
}

///|
/// 取 `metadata.deps` 依赖表。
///
/// 上游是「对象」形式（`{"moonbitlang/x":"0.4.40", ...}`），而对象的键序
/// 不保证稳定 —— 因此转成数组后**按包名排序**，让输出与测试都可复现。
fn metadata_deps(obj : Map[String, Json]) -> Array[(String, String)] {
  let pairs : Array[(String, String)] = match metadata_object(obj) {
    Some(m) =>
      match m.get("deps") {
        Some(Object(d)) =>
          d
          .to_array()
          .map(fn(pair) {
            let version = match pair.1 {
              String(v) => v
              _ => ""
            }
            (pair.0, version)
          })
        _ => []
      }
    None => []
  }
  pairs.sort_by(fn(a, b) { a.0.compare(b.0) })
  pairs
}

///|
/// 取 `versions` 版本历史（保持上游顺序，通常是新版本在前）。
/// 没有版本号的条目被丢弃。
fn metadata_versions(obj : Map[String, Json]) -> Array[String] {
  match obj.get("versions") {
    Some(Array(items)) =>
      items
      .map(fn(item) {
        match item {
          Object(m) => field_string(m, "version")
          _ => ""
        }
      })
      .filter(fn(v) { v != "" })
    _ => []
  }
}

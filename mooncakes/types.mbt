///|
/// 一个生态包的元数据，对应 mooncakes.io 搜索 API 返回数组中的一项。
///
/// 设计取舍：字段在上游缺失时降级为空字符串 / 0（见 `decode.mbt`），
/// 而不是让整个解析失败 —— 上游 schema 会演进，检索能力不应因为
/// 某个可选字段的增减而整体不可用。
pub(all) struct PackageHit {
  name : String
  version : String
  license : String
  repository : String
  description : String
  keywords : Array[String]
  downloads : Int
  created_at : String
  is_new : Bool
} derive(Debug, Eq)

///|
/// 单个包的详情，对应 `GET /api-new/v0/modules/<owner>/<name>`。
///
/// **重要事实（已实测，决定了本结构只能有这些字段）：**
/// - 上游的 `metadata.readme` **只是文件名**（例如 `"README.md"`），不是正文；
/// - 没有公开的「函数签名 / API 列表」端点 —— 逐个探测候选端点全部 404。
///
/// 所以本结构如实反映**能拿到**的信息：依赖表、版本历史、构建状态、
/// 许可证、仓库地址等。要读 API 只能去仓库 README —— 这一点由渲染层
/// 明确告知模型，而不是编造一份"API 摘要"。
pub(all) struct PackageDetail {
  /// 包标识（`owner/pkg`）。字段名用 `module_name` 而非 `module` ——
  /// `module` 是 MoonBit 的保留字。
  module_name : String
  version : String
  latest_version : String
  license : String
  repository : String
  description : String
  keywords : Array[String]
  created_at : String
  build_status : String
  yanked : Bool
  /// 依赖表，已按包名排序以保证输出稳定。
  deps : Array[(String, String)]
  /// 版本历史，保持上游顺序（通常新的在前）。
  versions : Array[String]
} derive(Debug, Eq)

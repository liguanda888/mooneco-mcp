///|
/// 一个生态包的元数据，对应 mooncakes.io 搜索 API 返回数组中的一项。
///
/// 设计取舍：字段在上游缺失时降级为空字符串 / 0（见 `decode.mbt`），
/// 而不是让整个解析失败 —— 上游 schema 会演进，检索能力不应因为
/// 某个可选字段的增减而整体不可用。
pub struct PackageHit {
  name : String
  version : String
  license : String
  repository : String
  description : String
  keywords : Array[String]
  downloads : Int
  created_at : String
} derive(Debug, Eq)

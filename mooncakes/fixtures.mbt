///|
/// 录制的 mooncakes.io 搜索 API 响应（查询词 `parquet`）。
///
/// 来源：2026-09-16 真实请求
///   `GET https://mooncakes.io/api-new/v0/search?kw=parquet&limit=2`
///
/// 为控制篇幅，`matched_packages` 内的 summary 片段已裁剪，
/// 但**本包会解析的每一个字段都保留了上游原值**（名称、版本、许可证、
/// 仓库、关键词、描述、下载量、创建时间），并保留了若干本包不解析的
/// 字段（`yanked`、`matched_package_count`）用于验证「忽略未知字段」的行为。
///
/// 命名注意：`let` 绑定必须小写开头 —— 全大写会被词法器当作类型/构造子。
pub let fixture_search_parquet : String = "[{\"name\":\"mizchi/parquet\",\"version\":\"0.2.1\",\"yanked\":false,\"license\":\"Apache-2.0\",\"repository\":\"https://github.com/mizchi/parquet\",\"keywords\":[\"moonbit\",\"parquet\"],\"description\":\"Parquet reader/writer for MoonBit.\",\"created_at\":\"2026-04-25T11:15:48.797751\",\"downloads\":1676,\"matched_package_count\":4},{\"name\":\"codeworm96/magpiedb\",\"version\":\"0.2.0\",\"yanked\":false,\"license\":\"Apache-2.0\",\"repository\":\"https://github.com/codeworm96/magpiedb\",\"keywords\":[\"sql\",\"database\",\"json\",\"csv\",\"parquet\"],\"description\":\"vibe coded lightweight OLAP database\",\"created_at\":\"2026-04-20T06:57:07.939677\",\"downloads\":29,\"matched_package_count\":7}]"

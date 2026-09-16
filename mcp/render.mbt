///|
/// 工具结果的构造与渲染。
///
/// 都是纯函数：给定数据产生字符串，因此可以逐条单元测试。
/// 输出面向**模型**阅读，所以格式要紧凑、信息密度高、并给出下一步提示。

///|
/// 构造 `tools/call` 的响应。
///
/// MCP 规定结果必须包在 `content` 数组里，且用 `isError` 标明失败——
/// 失败也走正常响应通道，而不是 JSON-RPC 错误，这样模型能看到失败原因。
pub fn tool_result(
  id : Json,
  text : String,
  is_error? : Bool = false,
) -> String {
  let flag = if is_error { "true" } else { "false" }
  success_response(
    id,
    "{\"content\":[{\"type\":\"text\",\"text\":" +
    @json.to_json(text).stringify() +
    "}],\"isError\":" +
    flag +
    "}",
  )
}

///|
/// 把检索结果渲染成给模型读的文本。
///
/// 设计要点：
/// - 每条结果给出**包名、版本、许可证、下载量、发布时间**，让模型能自行权衡；
/// - 说明相关结果可能因为"没有文本匹配"而被过滤掉，避免模型误以为生态里没有；
/// - 结尾提示下一步该调哪个工具，减少模型的无效尝试。
pub fn render_search_results(
  intent : StringView,
  hits : Array[@mooncakes.PackageHit],
) -> String {
  if hits.length() == 0 {
    return "No package matched \"" +
      intent.to_owned() +
      "\". Try a broader term or a synonym, or use search_packages with a different wording."
  }
  let buf = StringBuilder::StringBuilder()
  buf.write_string(hits.length().to_string())
  buf.write_string(" package(s) for \"")
  buf.write_string(intent.to_owned())
  buf.write_string("\":\n")
  let mut index = 1
  for hit in hits {
    buf.write_string("\n")
    buf.write_string(index.to_string())
    buf.write_string(". ")
    buf.write_string(hit.name)
    buf.write_string(" @ ")
    buf.write_string(hit.version)
    buf.write_string(" — ")
    buf.write_string(
      if hit.license == "" {
        "license unknown"
      } else {
        hit.license
      },
    )
    buf.write_string(", ")
    buf.write_string(hit.downloads.to_string())
    buf.write_string(" downloads, published ")
    buf.write_string(
      if hit.created_at.length() >= 10 {
        // 只显示日期部分（created_at 形如 2026-04-25T11:15:48）。
        // 已先用 length() >= 10 做过边界检查，切片安全。
        hit.created_at[:10].to_owned()
      } else {
        hit.created_at
      },
    )
    if hit.is_new {
      buf.write_string(" [new]")
    }
    buf.write_string("\n   ")
    buf.write_string(hit.description)
    if hit.repository != "" {
      buf.write_string("\n   ")
      buf.write_string(hit.repository)
    }
    buf.write_string("\n")
    index = index + 1
  }
  buf.write_string(
    "\nUse get_package_api to read the real API surface of one of these before writing code.",
  )
  buf.to_string()
}

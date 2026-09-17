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
    "\nUse get_package_api to see its dependency table, version history and repository before writing code.",
  )
  buf.to_string()
}

///|
/// 把包详情渲染成给模型读的文本。
///
/// **必须如实说明能力边界**：mooncakes.io 的公开 API 不提供函数签名，
/// 也不提供 README 正文（`metadata.readme` 只是文件名）。
/// 所以这里报告能拿到的事实，并明确指向仓库 README —— 而不是编一份
/// 看起来很专业的"API 摘要"。让模型去读真实来源，比给它编的摘要安全。
pub fn render_package_detail(detail : @mooncakes.PackageDetail) -> String {
  let buf = StringBuilder::StringBuilder()
  buf.write_string(detail.module_name)
  buf.write_string(" @ ")
  buf.write_string(detail.version)
  if detail.latest_version != "" && detail.latest_version != detail.version {
    buf.write_string("   (latest: ")
    buf.write_string(detail.latest_version)
    buf.write_string(")")
  }
  if detail.yanked {
    buf.write_string("   [YANKED]")
  }
  buf.write_string("\n")
  write_field(buf, "Description", detail.description)
  write_field(buf, "License", detail.license)
  write_field(buf, "Repository", detail.repository)
  if detail.keywords.length() > 0 {
    write_field(buf, "Keywords", detail.keywords.join(", "))
  }
  write_field(buf, "Published", date_part(detail.created_at))
  write_field(buf, "Build status", detail.build_status)
  buf.write_string("\nDependencies (")
  buf.write_string(detail.deps.length().to_string())
  buf.write_string("):\n")
  if detail.deps.length() == 0 {
    buf.write_string("  (none)\n")
  } else {
    for dep in detail.deps {
      buf.write_string("  ")
      buf.write_string(dep.0)
      buf.write_string("  ")
      buf.write_string(dep.1)
      buf.write_string("\n")
    }
  }
  buf.write_string("\nVersion history (")
  buf.write_string(detail.versions.length().to_string())
  buf.write_string(", newest first):\n  ")
  buf.write_string(detail.versions.join(", "))
  buf.write_string("\n")
  buf.write_string(
    "\nNote: the mooncakes.io API exposes no function signatures, so this tool cannot list the API surface. Read the repository README for that",
  )
  if detail.repository != "" {
    buf.write_string(": ")
    buf.write_string(detail.repository)
  } else {
    buf.write_string(".")
  }
  buf.to_string()
}

///|
/// 写一行 `名称 : 值`；值为空则整行省略，避免输出里出现无意义的空字段。
fn write_field(buf : StringBuilder, label : String, value : String) -> Unit {
  if value != "" {
    buf.write_string("  ")
    buf.write_string(label)
    buf.write_string(": ")
    buf.write_string(value)
    buf.write_string("\n")
  }
}

///|
/// 只取 ISO 时间的日期部分（`2026-04-25T11:15:48` → `2026-04-25`）。
/// 不足 10 个字符时原样返回。
pub fn date_part(stamp : String) -> String {
  if stamp.length() >= 10 {
    stamp[:10].to_owned()
  } else {
    stamp
  }
}

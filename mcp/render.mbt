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
///
/// 解决办法不是编一份"API 摘要"，而是**把仓库 README 取回来交给模型**——
/// MoonBit 包的 API 用法恰恰写在 README 里。`readme` 参数就是上层
/// 通过 `net.fetch_readme` 取到的正文；取不到时降级为只给事实 + 明确说明。
pub fn render_package_detail(
  detail : @mooncakes.PackageDetail,
  readme? : String? = None,
) -> String {
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
  match readme {
    Some(text) => {
      buf.write_string("\n")
      buf.write_string(render_readme_highlights(text, detail.repository))
    }
    None => {
      // 降级路径也要说清楚为什么没有 —— 模型据此知道该去哪里找。
      buf.write_string(
        "\nREADME: could not be fetched from the repository, so the API surface is not included here.",
      )
      if detail.repository != "" {
        buf.write_string(" Read it at: ")
        buf.write_string(detail.repository)
      }
      buf.write_string("\n")
    }
  }
  buf.to_string()
}

///|
/// README 正文的字符上限。
///
/// 为什么截断：README 动辄上万字符，整份塞进上下文会挤掉真正需要的内容。
/// 前若干字符通常已覆盖标题、简介、安装与快速上手 —— 也就是最像
/// "怎么用这个包"的部分；同时用章节导航告诉模型后面还有什么。
pub let readme_char_limit : Int = 1800

///|
/// 渲染 README 要点：**章节导航 + 正文前若干字符**。
///
/// 章节导航是"要点"里信息密度最高的部分：它让模型一眼看到这份 README
/// 是否讲了 API、用法、限制，从而决定要不要去读全文。
pub fn render_readme_highlights(readme : StringView, source : String) -> String {
  let buf = StringBuilder::StringBuilder()
  let headings = extract_headings(readme)
  if headings.length() > 0 {
    buf.write_string("README sections: ")
    buf.write_string(headings.join(" | "))
    buf.write_string("\n")
  }
  let total = char_count(readme)
  buf.write_string("\nREADME content")
  if total > readme_char_limit {
    buf.write_string(" (first ")
    buf.write_string(readme_char_limit.to_string())
    buf.write_string(" of ")
    buf.write_string(total.to_string())
    buf.write_string(" characters)")
  }
  buf.write_string(":\n")
  buf.write_string(truncate_chars(readme, readme_char_limit))
  if total > readme_char_limit {
    buf.write_string("\n... (truncated)")
    if source != "" {
      buf.write_string(" Full README: ")
      buf.write_string(source)
    }
  }
  buf.write_string("\n")
  buf.to_string()
}

///|
/// 从 Markdown 提取章节标题（`#` 开头），最多 12 个。
/// 同时兼容 `#` / `##` / `###`；空标题忽略。
pub fn extract_headings(markdown : StringView) -> Array[String] {
  let out : Array[String] = []
  for line in markdown.split("\n") {
    let trimmed = line.trim()
    if trimmed.has_prefix("#") {
      let title = trimmed.trim_start(chars="#").trim().to_owned()
      if title != "" && out.length() < 12 {
        out.push(title)
      }
    }
  }
  out
}

///|
/// 按**字符数**截断（不是字节数）。
///
/// 为什么强调这一点：按字节切会把一个汉字切成两半，产出无效的 UTF-8。
/// 逐字符写入天然对齐字符边界。
pub fn truncate_chars(text : StringView, limit : Int) -> String {
  let buf = StringBuilder::StringBuilder()
  let mut count = 0
  for ch in text {
    if count >= limit {
      break
    }
    buf.write_char(ch)
    count = count + 1
  }
  buf.to_string()
}

///|
/// 字符数（不是字节数）。
pub fn char_count(text : StringView) -> Int {
  let mut n = 0
  for _ch in text {
    n = n + 1
  }
  n
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

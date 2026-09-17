///|
/// 白盒测试：MCP 协议行为、工具结果渲染。
///
/// **纯逻辑、不触网、不起进程** —— 这正是把协议层与传输/执行分开的收益：
/// 协议是否正确可以独立验证，评审也不需要任何外部环境。

///|
/// 测试辅助：把 dispatch 的结果收敛成"要写出的 JSON"。
/// 通知返回 None；工具调用在协议层不产生 JSON，用占位符表示以便断言分发正确。
fn respond(text : StringView) -> String? {
  match dispatch(text) {
    Respond(json) => Some(json)
    NoResponse => None
    CallTool(_, _, _) => Some("<call-tool>")
  }
}

///|
/// 测试辅助：构造包元数据，避免每个用例重复写全字段。
fn hit(
  name : String,
  description? : String = "",
  downloads? : Int = 0,
  license? : String = "Apache-2.0",
  repository? : String = "",
  created_at? : String = "2026-04-25T11:15:48",
  is_new? : Bool = false,
) -> @mooncakes.PackageHit {
  {
    name,
    version: "0.2.1",
    license,
    repository,
    description,
    keywords: [],
    downloads,
    created_at,
    is_new,
  }
}

// ---------------------------------------------------------------- 请求解析

///|
test "parse_request reads method and id" {
  let req = parse_request(
    "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"initialize\"}",
  )
  match req {
    Some(r) => {
      assert_eq(r.method_name, "initialize")
      assert_true(r.id is Some(_))
    }
    None => assert_true(false)
  }
}

///|
test "parse_request accepts a string id" {
  let req = parse_request(
    "{\"jsonrpc\":\"2.0\",\"id\":\"abc\",\"method\":\"ping\"}",
  )
  match req {
    Some(r) => assert_eq(r.method_name, "ping")
    None => assert_true(false)
  }
}

///|
test "parse_request rejects invalid JSON" {
  assert_true(parse_request("{oops") is None)
}

///|
test "parse_request requires jsonrpc 2.0" {
  assert_true(parse_request("{\"method\":\"ping\"}") is None)
  assert_true(
    parse_request("{\"jsonrpc\":\"1.0\",\"method\":\"ping\"}") is None,
  )
}

///|
test "parse_request requires a method" {
  assert_true(parse_request("{\"jsonrpc\":\"2.0\",\"id\":1}") is None)
}

// ---------------------------------------------------------------- 分发

///|
test "dispatch answers initialize" {
  match respond("{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"initialize\"}") {
    Some(text) => {
      assert_true(text.contains("\"protocolVersion\""))
      assert_true(text.contains("mooneco-mcp"))
      assert_true(text.contains("\"id\":1"))
    }
    None => assert_true(false)
  }
}

///|
test "dispatch does not answer notifications" {
  // MCP 客户端在 initialize 之后会发这条通知，规范要求不得回应。
  assert_true(
    respond("{\"jsonrpc\":\"2.0\",\"method\":\"notifications/initialized\"}")
    is None,
  )
}

///|
test "dispatch returns a parse error for garbage" {
  match respond("not json") {
    Some(text) => {
      assert_true(text.contains("-32700"))
      assert_true(text.contains("\"id\":null"))
    }
    None => assert_true(false)
  }
}

///|
test "dispatch reports unknown methods" {
  match respond("{\"jsonrpc\":\"2.0\",\"id\":7,\"method\":\"nope\"}") {
    Some(text) => {
      assert_true(text.contains("-32601"))
      assert_true(text.contains("nope"))
    }
    None => assert_true(false)
  }
}

///|
test "tools/list advertises all four tools" {
  match respond("{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"tools/list\"}") {
    Some(text) =>
      for name in tool_names {
        assert_true(text.contains("\"name\":\"" + name + "\""))
      }
    None => assert_true(false)
  }
}

///|
test "tools/call is delegated to the caller instead of executed" {
  // 协议层不执行工具——它只报告"需要执行哪个工具、参数是什么"。
  let out = dispatch(
    "{\"jsonrpc\":\"2.0\",\"id\":3,\"method\":\"tools/call\",\"params\":{\"name\":\"search_packages\",\"arguments\":{\"intent\":\"parquet\",\"limit\":5}}}",
  )
  match out {
    CallTool(id, name, args) => {
      assert_eq(name, "search_packages")
      assert_true(id is Number(_))
      assert_eq(arg_string(args, "intent"), Some("parquet"))
      assert_eq(arg_int(args, "limit"), Some(5))
    }
    _ => assert_true(false)
  }
}

///|
test "tools/call without a name is an invalid-params error" {
  match respond("{\"jsonrpc\":\"2.0\",\"id\":3,\"method\":\"tools/call\"}") {
    Some(text) => assert_true(text.contains("-32602"))
    None => assert_true(false)
  }
}

///|
test "tools/call with missing arguments yields None for that key" {
  let out = dispatch(
    "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"tools/call\",\"params\":{\"name\":\"search_packages\",\"arguments\":{}}}",
  )
  match out {
    CallTool(_, _, args) => {
      assert_true(arg_string(args, "intent") is None)
      assert_true(arg_int(args, "limit") is None)
    }
    _ => assert_true(false)
  }
}

// ---------------------------------------------------------------- 工具目录

///|
test "the tool catalogue is valid JSON with four complete entries" {
  // 直接解析字面量：手拼 JSON 最容易出语法错，这里把它钉住。
  let parsed : Json? = Some(@json.parse(tools_list_result)) catch { _ => None }
  let tools = match parsed {
    Some(Object(m)) =>
      match m.get("tools") {
        Some(Array(a)) => a
        _ => []
      }
    _ => []
  }
  assert_eq(tools.length(), 4)
  for tool in tools {
    match tool {
      Object(m) => {
        assert_true(m.get("name") is Some(_))
        assert_true(m.get("description") is Some(_))
        assert_true(m.get("inputSchema") is Some(_))
      }
      _ => assert_true(false)
    }
  }
}

///|
test "initialize result exposes the module version" {
  assert_true(initialize_result().contains(@mooneco.version))
}

// ---------------------------------------------------------------- 结果渲染

///|
test "tool_result wraps text in the MCP content shape" {
  let out = tool_result(@json.to_json(1), "hello", is_error=false)
  assert_true(out.contains("\"content\":[{\"type\":\"text\""))
  assert_true(out.contains("\"isError\":false"))
  // 文本必须被正确转义
  let escaped = tool_result(@json.to_json(1), "say \"hi\"", is_error=false)
  assert_true(escaped.contains("say \\\"hi\\\""))
}

///|
test "tool_result marks failures" {
  assert_true(
    tool_result(@json.to_json(1), "boom", is_error=true).contains(
      "\"isError\":true",
    ),
  )
}

///|
test "render_search_results reports each package with its facts" {
  let text = render_search_results("parquet", [
    hit(
      "mizchi/parquet",
      description="Parquet reader/writer for MoonBit.",
      downloads=1676,
      repository="https://github.com/mizchi/parquet",
    ),
  ])
  assert_true(text.contains("mizchi/parquet @ 0.2.1"))
  assert_true(text.contains("Apache-2.0"))
  assert_true(text.contains("1676 downloads"))
  assert_true(text.contains("2026-04-25"))
  assert_true(text.contains("Parquet reader/writer for MoonBit."))
  assert_true(text.contains("https://github.com/mizchi/parquet"))
  // 结尾应引导模型使用下一个工具
  assert_true(text.contains("get_package_api"))
}

///|
test "render_search_results explains an empty result" {
  let text = render_search_results("zzzz", [])
  assert_true(text.contains("No package matched"))
  assert_true(text.contains("zzzz"))
}

///|
test "render_search_results marks new packages" {
  let text = render_search_results("x", [hit("a/b", is_new=true)])
  assert_true(text.contains("[new]"))
}

// ---------------------------------------------------------------- 包详情渲染

///|
/// 测试辅助：构造包详情（取值取自录制的真实响应）。
fn detail() -> @mooncakes.PackageDetail {
  {
    module_name: "mizchi/parquet",
    version: "0.2.1",
    latest_version: "0.2.1",
    license: "Apache-2.0",
    repository: "https://github.com/mizchi/parquet",
    description: "Parquet reader/writer for MoonBit.",
    keywords: ["moonbit", "parquet"],
    created_at: "2026-04-25T11:15:48.797751",
    build_status: "success",
    yanked: false,
    deps: [("f4ah6o/duckdb", "0.6.0"), ("moonbitlang/x", "0.4.40")],
    versions: ["0.2.1", "0.2.0", "0.1.0"],
  }
}

///|
test "render_package_detail reports the verifiable facts" {
  let text = render_package_detail(detail())
  assert_true(text.contains("mizchi/parquet @ 0.2.1"))
  assert_true(text.contains("Apache-2.0"))
  assert_true(text.contains("https://github.com/mizchi/parquet"))
  assert_true(text.contains("2026-04-25"))
  assert_true(text.contains("Build status: success"))
  assert_true(text.contains("moonbitlang/x  0.4.40"))
  assert_true(text.contains("f4ah6o/duckdb  0.6.0"))
  assert_true(text.contains("0.2.1, 0.2.0, 0.1.0"))
}

///|
test "render_package_detail is honest about the missing API surface" {
  // 上游不提供函数签名。渲染必须把这一点说出来，并指向真实来源，
  // 而不是编一份看起来很专业的"API 摘要"—— 这正是本项目的立意。
  let text = render_package_detail(detail())
  assert_true(text.contains("exposes no function signatures"))
  assert_true(text.contains("Read the repository README"))
}

///|
test "render_package_detail shows the latest version when it differs" {
  let older = { ..detail(), version: "0.1.0", }
  assert_true(render_package_detail(older).contains("(latest: 0.2.1)"))
}

///|
test "render_package_detail flags a yanked release" {
  let yanked = { ..detail(), yanked: true, }
  assert_true(render_package_detail(yanked).contains("[YANKED]"))
}

///|
test "render_package_detail omits empty fields instead of printing blank lines" {
  let sparse = {
    ..detail(),
    description: "",
    license: "",
    repository: "",
    keywords: [],
  }
  let text = render_package_detail(sparse)
  assert_true(!text.contains("Description"))
  assert_true(!text.contains("License"))
  assert_true(!text.contains("Keywords"))
  // 空依赖表要有明确说明，而不是留下一段空白
  let no_deps = { ..detail(), deps: [], }
  assert_true(render_package_detail(no_deps).contains("(none)"))
}

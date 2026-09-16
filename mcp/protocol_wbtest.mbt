///|
/// 白盒测试：MCP 协议行为。
///
/// **纯逻辑、不触网、不起进程** —— 这正是把协议层与 STDIO 传输分开的收益：
/// 协议是否正确可以独立验证，评审也不需要任何外部环境。

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

///|
test "handle_message answers initialize" {
  let out = handle_message(
    "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"initialize\"}",
  )
  match out {
    Some(text) => {
      assert_true(text.contains("\"protocolVersion\""))
      assert_true(text.contains("mooneco-mcp"))
      assert_true(text.contains("\"id\":1"))
    }
    None => assert_true(false)
  }
}

///|
test "handle_message does not answer notifications" {
  // MCP 客户端在 initialize 之后会发这条通知，规范要求不得回应。
  let out = handle_message(
    "{\"jsonrpc\":\"2.0\",\"method\":\"notifications/initialized\"}",
  )
  assert_true(out is None)
}

///|
test "handle_message returns a parse error for garbage" {
  match handle_message("not json") {
    Some(text) => {
      assert_true(text.contains("-32700"))
      assert_true(text.contains("\"id\":null"))
    }
    None => assert_true(false)
  }
}

///|
test "handle_message reports unknown methods" {
  match handle_message("{\"jsonrpc\":\"2.0\",\"id\":7,\"method\":\"nope\"}") {
    Some(text) => {
      assert_true(text.contains("-32601"))
      assert_true(text.contains("nope"))
    }
    None => assert_true(false)
  }
}

///|
test "tools/list advertises all four tools" {
  match
    handle_message("{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"tools/list\"}") {
    Some(text) =>
      for name in tool_names {
        assert_true(text.contains("\"name\":\"" + name + "\""))
      }
    None => assert_true(false)
  }
}

///|
test "tools/call without a tool name is an invalid-params error" {
  match
    handle_message("{\"jsonrpc\":\"2.0\",\"id\":3,\"method\":\"tools/call\"}") {
    Some(text) => assert_true(text.contains("-32602"))
    None => assert_true(false)
  }
}

///|
test "the tool catalogue is valid JSON with four complete entries" {
  // 直接解析字面量：手拼 JSON 最容易出语法错，这里把它钉住。
  // 解析失败时 parsed 为 None，tools 退化成空数组 —— 断言会失败并指出问题。
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

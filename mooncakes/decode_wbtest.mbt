///|
/// 白盒测试：全部基于录制的 fixture，**不触网**。
/// 这样评审在断网环境下也能完整复跑本套件（验收标准第 3 条）。

///|
test "decode_search parses a recorded API response" {
  let hits = decode_search(fixture_search_parquet)
  assert_eq(hits.length(), 2)
  let first = hits[0]
  assert_eq(first.name, "mizchi/parquet")
  assert_eq(first.version, "0.2.1")
  assert_eq(first.license, "Apache-2.0")
  assert_eq(first.repository, "https://github.com/mizchi/parquet")
  assert_eq(first.description, "Parquet reader/writer for MoonBit.")
  assert_eq(first.keywords, ["moonbit", "parquet"])
  assert_eq(first.downloads, 1676)
  assert_eq(first.created_at, "2026-04-25T11:15:48.797751")
}

///|
test "decode_search keeps every hit in order" {
  let hits = decode_search(fixture_search_parquet)
  assert_eq(hits[1].name, "codeworm96/magpiedb")
  assert_eq(hits[1].keywords, ["sql", "database", "json", "csv", "parquet"])
  assert_eq(hits[1].downloads, 29)
}

///|
test "decode_search returns empty array on malformed JSON" {
  assert_eq(decode_search("{ this is not json").length(), 0)
}

///|
test "decode_search returns empty array when the root is not an array" {
  assert_eq(decode_search("{\"name\":\"a/b\"}").length(), 0)
}

///|
test "decode_search tolerates missing optional fields" {
  let hits = decode_search("[{\"name\":\"a/b\",\"downloads\":3}]")
  assert_eq(hits.length(), 1)
  assert_eq(hits[0].name, "a/b")
  assert_eq(hits[0].downloads, 3)
  assert_eq(hits[0].license, "")
  assert_eq(hits[0].repository, "")
  assert_eq(hits[0].keywords.length(), 0)
}

///|
test "decode_search skips array elements that are not objects" {
  let hits = decode_search("[1,\"x\",{\"name\":\"a/b\"},null,[],true]")
  assert_eq(hits.length(), 1)
  assert_eq(hits[0].name, "a/b")
}

///|
test "decode_search drops keyword entries that are not strings" {
  let hits = decode_search(
    "[{\"name\":\"a/b\",\"keywords\":[\"ok\",1,null,\"two\"]}]",
  )
  assert_eq(hits[0].keywords, ["ok", "two"])
}

///|
test "decode_search defaults a mistyped field instead of failing" {
  let hits = decode_search("[{\"name\":123,\"downloads\":\"many\"}]")
  assert_eq(hits.length(), 1)
  assert_eq(hits[0].name, "")
  assert_eq(hits[0].downloads, 0)
}

// ---------------------------------------------------------------- 包详情

///|
test "decode_module parses a recorded detail response" {
  match decode_module(fixture_module_parquet) {
    Some(d) => {
      assert_eq(d.module_name, "mizchi/parquet")
      assert_eq(d.version, "0.2.1")
      assert_eq(d.latest_version, "0.2.1")
      assert_eq(d.license, "Apache-2.0")
      assert_eq(d.repository, "https://github.com/mizchi/parquet")
      assert_eq(d.description, "Parquet reader/writer for MoonBit.")
      assert_eq(d.keywords, ["moonbit", "parquet"])
      assert_eq(d.build_status, "success")
      assert_eq(d.yanked, false)
      assert_eq(d.created_at, "2026-04-25T11:15:48.797751")
    }
    None => assert_true(false)
  }
}

///|
test "decode_module sorts the dependency table by package name" {
  // 上游 deps 是对象，键序不保证稳定 —— 解析后必须排序才可复现。
  match decode_module(fixture_module_parquet) {
    Some(d) =>
      assert_eq(d.deps, [
        ("f4ah6o/duckdb", "0.6.0"),
        ("moonbitlang/x", "0.4.40"),
      ])
    None => assert_true(false)
  }
}

///|
test "decode_module reads the version history" {
  match decode_module(fixture_module_parquet) {
    Some(d) => assert_eq(d.versions, ["0.2.1", "0.2.0", "0.1.0"])
    None => assert_true(false)
  }
}

///|
test "decode_module ignores unknown upstream fields" {
  // fixture 里带了一个明显合成的 unknown_future_field
  match decode_module(fixture_module_parquet) {
    Some(d) => assert_eq(d.module_name, "mizchi/parquet")
    None => assert_true(false)
  }
}

///|
test "decode_module returns None for invalid JSON" {
  assert_true(decode_module("{nope") is None)
}

///|
test "decode_module returns None when the module field is missing" {
  // 例如误把错误页、或搜索响应当成详情响应
  assert_true(decode_module("{\"version\":\"1.0.0\"}") is None)
  assert_true(decode_module("[1,2,3]") is None)
  assert_true(decode_module("\"just a string\"") is None)
}

///|
test "decode_module tolerates a missing metadata object" {
  match decode_module("{\"module\":\"a/b\"}") {
    Some(d) => {
      assert_eq(d.module_name, "a/b")
      assert_eq(d.license, "")
      assert_eq(d.repository, "")
      assert_eq(d.deps.length(), 0)
      assert_eq(d.versions.length(), 0)
    }
    None => assert_true(false)
  }
}

///|
test "decode_module drops version entries without a version string" {
  let raw = "{\"module\":\"a/b\",\"versions\":[{\"version\":\"1.0.0\"},{\"yanked\":true},{\"version\":\"0.9.0\"}]}"
  match decode_module(raw) {
    Some(d) => assert_eq(d.versions, ["1.0.0", "0.9.0"])
    None => assert_true(false)
  }
}

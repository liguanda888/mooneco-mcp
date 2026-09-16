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

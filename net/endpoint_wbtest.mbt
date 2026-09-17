///|
/// 白盒测试：URL 构造与百分号编码，**不触网**。

///|
test "search_url builds the documented endpoint" {
  assert_eq(
    search_url("parquet", 10),
    "https://mooncakes.io/api-new/v0/search?kw=parquet&limit=10",
  )
}

///|
test "search_url percent-encodes a space" {
  assert_eq(
    search_url("http server", 5),
    "https://mooncakes.io/api-new/v0/search?kw=http%20server&limit=5",
  )
}

///|
test "percent_encode leaves unreserved characters untouched" {
  assert_eq(percent_encode("aZ0-_.~"), "aZ0-_.~")
}

///|
test "percent_encode encodes reserved characters" {
  assert_eq(percent_encode("a b"), "a%20b")
  assert_eq(percent_encode("a/b"), "a%2Fb")
  assert_eq(percent_encode("a&b=c"), "a%26b%3Dc")
  assert_eq(percent_encode("100%"), "100%25")
}

///|
test "percent_encode keeps non-ASCII text as-is" {
  // 设计取舍：非 ASCII 直传 UTF-8，不自建 UTF-8 编码器
  assert_eq(percent_encode("中文"), "中文")
}

///|
test "module_url keeps the owner slash" {
  assert_eq(
    module_url("mizchi/parquet"),
    "https://mooncakes.io/api-new/v0/modules/mizchi/parquet",
  )
}

// ---------------------------------------------------------------- README 地址

///|
test "github_owner_repo handles the common repository URL forms" {
  // 这些形式都实测过（raw 地址返回 200）
  assert_eq(
    github_owner_repo("https://github.com/mizchi/parquet"),
    Some(("mizchi", "parquet")),
  )
  assert_eq(
    github_owner_repo("https://github.com/mizchi/parquet/"),
    Some(("mizchi", "parquet")),
  )
  assert_eq(
    github_owner_repo("https://github.com/mizchi/parquet.git"),
    Some(("mizchi", "parquet")),
  )
  assert_eq(
    github_owner_repo("git@github.com:mizchi/parquet.git"),
    Some(("mizchi", "parquet")),
  )
}

///|
test "github_owner_repo ignores extra path segments" {
  // 例如指向子目录的地址
  assert_eq(
    github_owner_repo("https://github.com/mizchi/parquet/tree/main/src"),
    Some(("mizchi", "parquet")),
  )
}

///|
test "github_owner_repo returns None for unknown hosts or bad input" {
  // 只认 github.com：其它平台的 raw 规律未经验证，宁可降级也不猜
  assert_true(github_owner_repo("https://gitlab.com/a/b") is None)
  assert_true(github_owner_repo("https://github.com/only-owner") is None)
  assert_true(github_owner_repo("") is None)
  assert_true(github_owner_repo("mizchi/parquet") is None)
}

///|
test "readme_url_candidates puts the reachable mirror before raw" {
  let urls = readme_url_candidates("mizchi", "parquet")
  assert_eq(urls.length(), 5)
  // 顺序即尝试顺序：jsDelivr 优先（中国大陆可直连），raw 殿后。
  // 实测 raw.githubusercontent.com 在国内是 TCP 连接被丢弃，不是 404。
  assert_eq(
    urls[0],
    "https://cdn.jsdelivr.net/gh/mizchi/parquet@main/README.mbt.md",
  )
  assert_eq(
    urls[2],
    "https://cdn.jsdelivr.net/gh/mizchi/parquet@master/README.md",
  )
  assert_eq(
    urls[3],
    "https://raw.githubusercontent.com/mizchi/parquet/main/README.md",
  )
  assert_eq(
    urls[4],
    "https://raw.githubusercontent.com/mizchi/parquet/master/README.md",
  )
}

///|
test "github_readme_api_url points at the official readme endpoint" {
  assert_eq(
    github_readme_api_url("mizchi", "parquet"),
    "https://api.github.com/repos/mizchi/parquet/readme",
  )
}

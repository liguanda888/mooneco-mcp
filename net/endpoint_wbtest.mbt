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

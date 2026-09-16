///|
/// 白盒测试：打分与排序，**纯逻辑、不触网**。

///|
/// 构造测试用的包元数据，避免每个用例重复写全字段。
fn hit(
  name : String,
  description? : String = "",
  keywords? : Array[String] = [],
  downloads? : Int = 0,
  is_new? : Bool = false,
) -> @mooncakes.PackageHit {
  {
    name,
    version: "0.1.0",
    license: "Apache-2.0",
    repository: "",
    description,
    keywords,
    downloads,
    created_at: "",
    is_new,
  }
}

///|
test "exact name match scores highest" {
  let exact = score(hit("parquet"), "parquet")
  let leaf = score(hit("mizchi/parquet"), "parquet")
  let contains = score(hit("mizchi/parquet-extra"), "parquet")
  assert_true(exact > leaf)
  assert_true(leaf > contains)
  assert_true(contains > 0)
}

///|
test "unrelated package scores zero" {
  assert_eq(score(hit("mizchi/parquet", downloads=100000), "sqlite"), 0)
}

///|
test "empty query scores zero" {
  assert_eq(score(hit("mizchi/parquet", downloads=1000), ""), 0)
}

///|
test "matching is case-insensitive" {
  assert_eq(
    score(hit("Mizchi/Parquet"), "PARQUET"),
    score(hit("mizchi/parquet"), "parquet"),
  )
}

///|
test "keyword match adds score" {
  let with_kw = score(hit("a/b", keywords=["sqlite"]), "sqlite")
  let without = score(hit("a/b"), "sqlite")
  assert_true(with_kw > without)
  assert_eq(without, 0)
}

///|
test "downloads are log-scaled not linear" {
  // 位数近似：29 -> 10 分，1676 -> 30 分（而不是 29 与 1676）
  let low = score(hit("a/b", downloads=29), "b")
  let high = score(hit("a/b", downloads=1676), "b")
  assert_eq(high - low, 20)
}

///|
test "new packages get a small bonus" {
  let fresh = score(hit("a/b", is_new=true), "b")
  let old = score(hit("a/b", is_new=false), "b")
  assert_eq(fresh - old, 20)
}

///|
test "package_leaf takes the last path segment" {
  assert_eq(package_leaf("mizchi/parquet"), "parquet")
  assert_eq(package_leaf("a/b/c"), "c")
  assert_eq(package_leaf("plain"), "plain")
}

///|
test "ascii_lower only folds A-Z" {
  assert_eq(ascii_lower("AbC1-_.~"), "abc1-_.~")
  assert_eq(ascii_lower("中文"), "中文")
}

///|
test "rank drops irrelevant hits" {
  let result = rank(
    [hit("mizchi/parquet"), hit("some/sqlite", downloads=99999)],
    "parquet",
  )
  assert_eq(result.length(), 1)
  assert_eq(result[0].name, "mizchi/parquet")
}

///|
test "rank orders by score then downloads then name" {
  let result = rank(
    [
      // 名称段匹配 -> 600 + 下载量分
      hit("a/parquet", downloads=100),
      // 名称包含但非段匹配 -> 300 + 下载量分
      hit("b/parquet-extra", downloads=100),
      // 名称段匹配但下载量更高
      hit("c/parquet", downloads=100000),
    ],
    "parquet",
  )
  assert_eq(result.length(), 3)
  // 下载量位数：100 -> 20 分，100000 -> 50 分
  // c 与 a 同为段匹配（600），c 下载量更高 -> c 在前
  assert_eq(result[0].name, "c/parquet")
  assert_eq(result[1].name, "a/parquet")
  assert_eq(result[2].name, "b/parquet-extra")
}

///|
test "rank is stable for equal scores" {
  let hits = [hit("b/x"), hit("a/x"), hit("c/x")]
  let first = rank(hits, "x").map(fn(h) { h.name })
  let second = rank(hits, "x").map(fn(h) { h.name })
  assert_eq(first, second)
  // 同分同下载量时按名称升序
  assert_eq(first, ["a/x", "b/x", "c/x"])
}

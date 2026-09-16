///|
/// 白盒测试：在包作用域内运行，可直接访问本包成员（无需包名前缀）。
/// 运行 `moon test` 执行，`moon test --update` 刷新快照。

///|
test "version is not empty" {
  assert_true(version.length() > 0)
}

///|
test "describe contains version" {
  assert_true(describe().contains(version))
}

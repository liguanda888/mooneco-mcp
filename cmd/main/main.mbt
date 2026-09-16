///|
/// MoonEco MCP 可执行入口。
///
/// 用法：
///   moon run cmd/main          # 本地运行
///   moon build --target native # 产出可执行文件
///
/// 注意：当前为 M0 骨架，M2 将实现 MCP 的 JSON-RPC over STDIO 事件循环。
fn main {
  println(@mooneco.describe())
  println("status: skeleton (M0) — MCP event loop lands in M2")
}

# 可复现演示说明

> 本文档的目标：**让评审在不看源码、不联网的前提下，用三条命令验证本项目确实能跑。**
> 对应验收标准第 3 条「能够运行」与第 6 条「AI 可解释」。

---

## 环境要求

| 项 | 要求 |
|---|---|
| MoonBit 工具链 | `moon 0.1.20260915` 或更高（[安装说明](https://www.moonbitlang.cn/download/)） |
| 操作系统 | Windows / Linux / macOS（原生后端） |
| 网络 | **单元测试不需要网络**；只有实际检索生态时才需要 |

安装工具链（Windows PowerShell）：

```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser; irm https://cli.moonbitlang.cn/install/powershell.ps1 | iex
```

---

## 三步复现

```bash
# 1. 类型检查（无需网络）
moon check

# 2. 跑全部单元测试 —— 全部基于录制的 fixture，不触网
moon test --target native

# 3. 构建并做 MCP 协议端到端冒烟测试
moon build --target native
sh scripts/smoke.sh
```

**第 2 步的预期输出**（数字会随开发推进增长）：

```
Total tests: 41, passed: 41, failed: 0.
```

**第 3 步的预期输出**：

```
MCP 冒烟测试：_build/native/debug/build/cmd/main/main
  ok   收到 3 条回应（通知未被回应）
  ok   initialize 返回 serverInfo
  ok   tools/list 含 search_packages
  ok   tools/list 含 get_package_api
  ok   tools/list 含 suggest_dependencies
  ok   tools/list 含 pack_project_context
  ok   未知方法返回 -32601
全部通过
```

---

## 手动验证协议（不依赖脚本）

服务器用 **MCP 的 STDIO 传输**：换行分隔的 JSON，一问一答。

```bash
# 往 stdin 喂 4 条消息，其中第 2 条是通知（按规范不应有回应）
printf '%s\n' \
  '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}' \
  '{"jsonrpc":"2.0","method":"notifications/initialized"}' \
  '{"jsonrpc":"2.0","id":2,"method":"tools/list"}' \
  '{"jsonrpc":"2.0","id":3,"method":"nope"}' \
| _build/native/debug/build/cmd/main/main
```

**应得到 3 行输出**（不是 4 行）：

```json
{"jsonrpc":"2.0","id":1,"result":{"protocolVersion":"2024-11-05","capabilities":{"tools":{}},"serverInfo":{"name":"mooneco-mcp","version":"0.1.0"}}}
{"jsonrpc":"2.0","id":2,"result":{"tools":[{"name":"search_packages", ...}]}}
{"jsonrpc":"2.0","id":3,"error":{"code":-32601,"message":"Method not found: nope"}}
```

**为什么"3 行而不是 4 行"是关键验证点**：JSON-RPC 规定通知不得被回应。
写错这一点会让客户端收到多余的响应而错位——这是 MCP 实现最常见的错误之一。

---

## 在 MCP 客户端中接入

服务器通过标准 MCP 协议通信，**任何 MCP 兼容客户端**都可以接入
（例如 Claude Code、Codex，或官方开源的 MCP Inspector）。配置形如：

```json
{
  "mcpServers": {
    "mooneco": {
      "command": "/绝对路径/_build/native/debug/build/cmd/main/main"
    }
  }
}
```

用官方 MCP Inspector 调试：

```bash
npx @modelcontextprotocol/inspector _build/native/debug/build/cmd/main/main
```

---

## 当前实现状态（诚实说明）

| 能力 | 状态 |
|---|---|
| MCP 协议层（`initialize` / `tools/list` / 通知 / 错误码） | ✅ 已实现并测试 |
| 工具清单（四个工具的英文描述与入参 schema） | ✅ 已实现并测试 |
| mooncakes.io 响应解析（宽容解析） | ✅ 已实现并测试 |
| 相关性打分与稳定排序 | ✅ 已实现并测试 |
| HTTPS 客户端（原生，无 FFI） | ✅ 已实现 |
| **`tools/call` → `search_packages`** | ✅ **已实现，联网检索真实生效** |
| `tools/call` → 其余三个工具 | 🚧 返回可解释的"尚未实现"错误 |
| 本地快照缓存 | 🚧 计划中 |
| `pack_project_context` | 🚧 计划中 |

`search_packages` 的真实输出（可直接复跑）：

```bash
echo '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"search_packages","arguments":{"intent":"parquet","limit":3}}}' \
| _build/native/debug/build/cmd/main/main
```

```
2 package(s) for "parquet":

1. mizchi/parquet @ 0.2.1 — Apache-2.0, 1676 downloads, published 2026-04-25
   Parquet reader/writer for MoonBit.
   https://github.com/mizchi/parquet

2. codeworm96/magpiedb @ 0.2.0 — Apache-2.0, 29 downloads, published 2026-04-20
   vibe coded lightweight OLAP database
   https://github.com/codeworm96/magpiedb

Use get_package_api to read the real API surface of one of these before writing code.
```

未实现的工具会回一条**协议级可解释的失败结果**（`isError: true`）而不是超时或崩溃——
这样客户端拿到的失败是能读懂、能应对的。

---

## 为什么测试可以在断网环境跑

`mooncakes/` 包解析与 `rank/` 包打分的测试**全部基于录制的 JSON fixture**
（见 `mooncakes/fixtures.mbt`，其中记录了真实 API 响应的字段与取值）。
只有 `net/` 包真正联网，而它刻意被隔离成单独一层。

这样做的收益：**协议与解析的正确性，不依赖于上游服务是否可用。**

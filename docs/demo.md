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

> Windows 上没有 `sh`：用 Git Bash 执行第 3 步，或直接运行
> `"C:\Program Files\Git\bin\bash.exe" scripts/smoke.sh`。
> 前两步在 PowerShell 里可以直接跑。

**第 2 步的预期输出**（数字会随开发推进增长）：

```
Total tests: 74, passed: 74, failed: 0.
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

（脚本会自己找 `main` 或 `main.exe`，所以这一行显示的路径随平台而变。）

---

## 手动验证协议（不依赖脚本）

服务器用 **MCP 的 STDIO 传输**：换行分隔的 JSON，一问一答。

> **Windows 用户注意**：PowerShell 往原生程序的 stdin 传字符串时会改动引号和编码，
> 直接 `'...' | main.exe` 会得到 `-32700 Parse error`。用下面的 PowerShell 片段，
> 或者改用 Git Bash / WSL 执行上面的 bash 片段。

```powershell
# PowerShell：以字节流写入，避免引号和编码被改写
$req = @(
  '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}'
  '{"jsonrpc":"2.0","method":"notifications/initialized"}'
  '{"jsonrpc":"2.0","id":2,"method":"tools/list"}'
  '{"jsonrpc":"2.0","id":3,"method":"nope"}'
) -join "`n"
$req | & ".\_build\native\debug\build\cmd\main\main.exe"
```

```bash
# bash / Git Bash / WSL：往 stdin 喂 4 条消息，其中第 2 条是通知（按规范不应有回应）
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
| **`tools/call` → `get_package_api`** | ✅ **已实现，返回依赖表 / 版本历史 / 构建状态 / 仓库 README 要点** |
| `tools/call` → `suggest_dependencies` / `pack_project_context` | 🚧 返回可解释的"尚未实现"错误 |
| 本地快照缓存 | 🚧 计划中 |

### 关于 `get_package_api` 的能力边界（重要且如实）

mooncakes.io 的公开 API **不提供函数签名**：包详情里 `metadata.readme` 的取值
只是文件名（`"README.md"`），逐个探测候选的 symbols / docs 端点也全部返回 404。

而 MoonBit 包的 API 用法恰恰写在**仓库的 README** 里。所以本工具的做法是：

1. 给出 mooncakes.io 上能核实的事实——依赖表、版本历史、许可证、构建状态、仓库地址；
2. 从包详情的 `repository` 字段推导出仓库地址，**把 README 取回来**，
   以「章节导航 + 正文（上限 1800 字符）」的形式交给模型；
3. 取不到时**明确说取不到**并给出仓库地址，**不编造 API 摘要**。

README 是多源获取的，按顺序尝试、第一个成功即用（实测于 2026-09-17，中国大陆网络）：

| 源 | 实测结果 |
|---|---|
| `api.github.com/repos/<owner>/<repo>/readme` | 200，约 7 秒 |
| `cdn.jsdelivr.net/gh/<owner>/<repo>@<branch>/README.md` | 200，约 2 秒 |
| `raw.githubusercontent.com/...` | **时通时不通**（同一天里 curl 连续 19.5 秒无响应，MoonBit 客户端又能拿到 200） |

只接受 **2xx** 响应：jsDelivr 冷缓存时先回一个 301，而 HTTP 客户端不跟随跳转，
把跳转页当成 README 比取不到更糟。每次尝试有 **8 秒超时** ——
因为 `raw.githubusercontent.com` 在国内的失败方式是连接被丢弃而不是返回 404，
没有超时的话一次工具调用会永久挂住。

> 这比给一份看起来专业的编造摘要安全得多：模型读到的是仓库里真实存在的文档，
> 而不是一个可能过期或虚构的接口描述。

`search_packages` 与 `get_package_api` 的真实输出（可直接复跑）：

```powershell
# PowerShell：先把请求写成无 BOM 的 UTF-8 文件，再用 cmd 的 type 送进 stdin。
# 不要用 '...' | main.exe —— PowerShell 传给原生程序的 stdio 会改写引号与编码，
# 结果是 -32700 Parse error。
$req = @(
  '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"search_packages","arguments":{"intent":"parquet","limit":2}}}'
  '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"get_package_api","arguments":{"name":"mizchi/parquet"}}}'
) -join "`n"
[System.IO.File]::WriteAllText("$PWD\req.jsonl", $req, [System.Text.UTF8Encoding]::new($false))
cmd /c "type req.jsonl | _build\native\debug\build\cmd\main\main.exe"
```

```
2 package(s) for "parquet":

1. mizchi/parquet @ 0.2.1 — Apache-2.0, 1678 downloads, published 2026-04-25
   Parquet reader/writer for MoonBit.
   https://github.com/mizchi/parquet

2. codeworm96/magpiedb @ 0.2.0 — Apache-2.0, 29 downloads, published 2026-04-20
   vibe coded lightweight OLAP database
   https://github.com/codeworm96/magpiedb

Use get_package_api to see its dependency table, version history and repository before writing code.
```

```
mizchi/parquet @ 0.2.1
  Description: Parquet reader/writer for MoonBit.
  License: Apache-2.0
  Repository: https://github.com/mizchi/parquet
  Keywords: moonbit, parquet
  Published: 2026-04-25
  Build status: success

Dependencies (2):
  f4ah6o/duckdb  0.6.0
  moonbitlang/x  0.4.40

Version history (3, newest first):
  0.2.1, 0.2.0, 0.1.0

README sections: mizchi/parquet | Status | Benchmark | Development | Browser Playground | License

README content (first 1800 of 2675 characters):
# mizchi/parquet
...
```

未实现的工具会回一条**协议级可解释的失败结果**（`isError: true`）而不是超时或崩溃——
这样客户端拿到的失败是能读懂、能应对的。

---

## 为什么测试可以在断网环境跑

`mooncakes/` 包解析与 `rank/` 包打分的测试**全部基于录制的 JSON fixture**
（见 `mooncakes/fixtures.mbt`，其中记录了真实 API 响应的字段与取值）。
只有 `net/` 包真正联网，而它刻意被隔离成单独一层。

这样做的收益：**协议与解析的正确性，不依赖于上游服务是否可用。**

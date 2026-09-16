# MoonContext MCP

**让 AI 准确理解 MoonBit 生态的 MCP Server。**

MoonBit 生态已有 2000+ 个包，但它们不在大模型的训练数据里。结果就是 AI 写 MoonBit 时会**编造不存在的 API**，或者**重复造轮子**。

MoonContext MCP 把「生态知识」和「项目上下文」这两件事交给 AI —— 一个 MCP Server，四个工具。

> 本项目参加 **2026 MoonBit 九月黑客松**。许可：[Apache-2.0](LICENSE)。

---

## 解决什么问题

| 痛点 | 表现 | MoonContext 的答案 |
|---|---|---|
| AI 不知道生态里有什么 | 幻觉 API、手写已有轮子 | `search_packages` / `suggest_dependencies` |
| AI 不知道某个包怎么用 | 猜函数签名、猜参数 | `get_package_api` |
| 上下文又贵又乱 | 整个仓库塞进去，超预算且低信噪比 | `pack_project_context` |

---

## 四个工具

| 工具 | 说明 |
|---|---|
| `search_packages(intent, limit)` | 按意图检索生态包。融合名称匹配、关键词、下载量、维护活跃度加权排序 |
| `get_package_api(name, version)` | 返回指定包的 API 摘要、依赖表与 README 要点 |
| `suggest_dependencies(requirement)` | 「我要做 X」→ 反查该用哪些包，并给出替代方案对比 |
| `pack_project_context(path, budget)` | 把项目压缩进 token 预算，按 import 相关性排序选取文件 |

---

## 典型用法

对 AI 说：

> 「用 MoonBit 解析 Parquet 并写入 SQLite。」

AI 会自动：

1. `suggest_dependencies("解析 Parquet 并写入 SQLite")`
   → `mizchi/parquet@0.2.1`、`Lfan-ke/moon-sqlite@0.2.2`（含许可证与下载量）
2. `get_package_api("mizchi/parquet", "0.2.1")`
   → 真实 API 摘要与依赖表，不再靠猜
3. `pack_project_context("./myproject", 32000)`
   → 按 import 相关性压进 32k token 预算
4. 基于**真实**的包与上下文写代码

---

## 技术栈

- **MoonBit** —— 全项目纯 MoonBit 实现，无 FFI
- **MCP（Model Context Protocol）** —— STDIO + JSON-RPC 2.0
- **数据源**：mooncakes.io 官方 JSON API
  - `GET https://mooncakes.io/api-new/v0/search?kw=<关键词>&limit=N`
  - `GET https://mooncakes.io/api-new/v0/modules/<owner>/<name>`
- **本地快照缓存**（TTL 过期）—— 保证断网也能复现

当前规划中，协议层计划复用社区包 [`colmugx/mcp`](https://mooncakes.io/docs/colmugx/mcp)（类型安全 MCP SDK，支持 STDIO/HTTP 双传输）；若不满足需求则自行实现最小 JSON-RPC 2.0 层。最终选型会在此处更新。

---

## 快速开始

> 🚧 开发中。以下命令将在里程碑达成后逐一可用。

```bash
# 1. 安装 MoonBit 工具链（Windows）
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser; irm https://cli.moonbitlang.cn/install/powershell.ps1 | iex

# 2. 构建
moon build --target native

# 3. 跑测试
moon test

# 4. 在 MCP 客户端中接入（示例）
#    Claude Code / Codex / Cursor 的 MCP 配置中指向构建出的可执行文件
```

---

## 开发计划与验收线

| 阶段 | 内容 | 状态 |
|---|---|---|
| M0 | 仓库骨架、`moon.mod`、构建与测试跑通 | 🚧 |
| M1 | mooncakes API 客户端 + 本地缓存 + 单元测试 | ⬜ |
| M2 | MCP Server 骨架（`initialize` / `tools/list` / `tools/call`）+ `search_packages` | ⬜ |
| M3 | `get_package_api` + `suggest_dependencies` | ⬜ |
| M4 | `pack_project_context` | ⬜ |
| M5 | 端到端测试 + 在 MCP 客户端实测接入 | ⬜ |
| M6 | 文档、可复现演示说明、演示录屏 | ⬜ |

**9/24 验收线**：四个工具可用、测试通过、README 可让评审独立跑起来、附演示录屏。

**后续（季度）**：语义检索、依赖图查询、发布到 MCP registry、编辑器插件。

---

## AI 使用说明

本项目使用 AI 辅助编码，但**目标、架构、技术选型与质量边界由作者把控**：

- 数据源选用官方 JSON API 而非爬 HTML，缓存选用「快照 + TTL」而非纯实时请求 —— 取舍理由见提交记录与文档
- 所有 AI 生成的代码必须通过测试；AI 给出的 API 名称一律以 mooncakes.io 实际返回为准
- 公开仓库保留完整 commits / Issues / PR，可追溯每个设计决策

---

## 项目文档

- [一页项目说明](docs/01-一页项目说明.md)

## 许可证

[Apache-2.0](LICENSE)

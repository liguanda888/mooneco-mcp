# MoonEco MCP

**让 AI 真正读懂 MoonBit 生态的 MCP Server。**

MoonBit 生态已有 2000+ 个包，但它们不在大模型的训练数据里。结果是 AI 写 MoonBit 时会**编造不存在的 API**，或者**重复实现生态里早就有的包**。

MoonEco MCP 让 AI 在动手写代码之前，先查到**真实的包、真实的 API**，并在 token 预算内拿到**理解 MoonBit 语义**的项目上下文。

> 本项目参加 **2026 MoonBit 九月黑客松**。许可：[Apache-2.0](LICENSE)。
> English version: [README.en.md](README.en.md)

---

## 我们的特色

| 特色 | 说明 |
|---|---|
| 🔍 **内置生态索引** | 覆盖 mooncakes.io 全量包，按**意图**检索，融合名称、关键词、描述匹配度与下载量加权排序，并标记新包（`is_new`） |
| 🚫 **零幻觉** | 包名、版本与依赖关系全部来自 mooncakes.io 的真实返回，**不依赖模型记忆**。上游不提供函数签名时，工具会**把仓库 README 取回来交给模型**——而不是编一份看起来专业的"API 摘要" |
| 🧠 **MoonBit 语义级上下文** | 打包项目上下文时，会把项目**实际用到的包的依赖与版本事实一并附上** —— 因为工具理解 MoonBit 的包结构，而不是单纯按文件切分 |
| 🔌 **离线可复现** | 本地快照缓存 + TTL；测试基于录制的 JSON fixture，不依赖实时网络，评审可独立复跑 |
| 🧩 **纯 MoonBit 实现** | 无 FFI，全项目 MoonBit，多后端可用 |

---

## 解决什么问题

| 痛点 | 表现 | MoonEco 的答案 |
|---|---|---|
| AI 不知道生态里有什么 | 幻觉 API、手写已有轮子 | `search_packages` / `suggest_dependencies` |
| AI 不知道某个包怎么用 | 猜函数签名、猜参数 | `get_package_api`（给真实依赖与版本，并指向仓库 README） |
| 上下文又贵又乱 | 整个仓库塞进去，超预算且低信噪比 | `pack_project_context` |

---

## 四个工具

| 工具 | 说明 |
|---|---|
| `search_packages` | 按意图检索生态包，带下载量、许可证与发布时间 |
| `get_package_api` | 返回可核实的事实（依赖表、版本历史、构建状态、许可证）+ **仓库 README 要点**（章节导航 + 正文截断），让 AI 拿到真实的 API 用法 |
| `suggest_dependencies` | 「我要做 X」→ 反查该用哪些包，并给出替代方案对比 |
| `pack_project_context` | 把项目压缩进 token 预算；**同时附上所用包的依赖与版本事实**，让上下文自带生态知识 |

工具的 `description` 与 `inputSchema` 均使用**英文** —— 它们由 AI 模型消费，英文的模型兼容性与调用准确率更好。

---

## 典型用法

对 AI 说：

> 「用 MoonBit 解析 Parquet 并写入 SQLite。」

AI 会自动：

1. 调用 `suggest_dependencies("解析 Parquet 并写入 SQLite")`
   → `mizchi/parquet@0.2.1`、`Lfan-ke/moon-sqlite@0.2.2`（含许可证与下载量）
2. 调用 `get_package_api("mizchi/parquet", "0.2.1")`
   → 真实依赖表与版本历史；工具会说明上游不提供函数签名，并给出仓库地址
3. 调用 `pack_project_context("./myproject", 32000)`
   → 压进 32k token 预算，并附上这些包的真实依赖与版本事实
4. 基于**真实存在**的包写代码，API 细节去仓库 README 核对

---

## 技术栈

- **MoonBit** —— 全项目纯 MoonBit 实现，无 FFI（满足验收标准第 1 条）
- **MCP（Model Context Protocol）** —— STDIO + JSON-RPC 2.0
- **数据源**：mooncakes.io 官方 JSON API（已实测可用）
  - `GET https://mooncakes.io/api-new/v0/search?kw=<关键词>&limit=N`
  - `GET https://mooncakes.io/api-new/v0/modules/<owner>/<name>`
- **本地快照缓存**（TTL 过期）—— 保证断网也能复现（满足验收标准第 3 条）

---

## 快速开始

> 🚧 开发中。以下命令将在里程碑达成后逐一可用。

```bash
# 1. 安装 MoonBit 工具链（Windows PowerShell）
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser; irm https://cli.moonbitlang.cn/install/powershell.ps1 | iex

# 2. 构建（build）
moon build --target native

# 3. 跑测试（test）
moon test

# 4. 在 MCP 客户端中接入
#    将构建出的可执行文件配置到 Claude Code、Codex 以及其他 MCP 兼容客户端中
```

---

## Dependencies & Attribution

This project follows the MoonBit ecosystem convention of depending on community
packages where they exist. All third-party dependencies and their licenses are
listed below (required by the contest's open-source compliance criterion).

| Package | Version | License | Purpose |
|---|---|---|---|
| [`marianoguerra/mcp`](https://mooncakes.io/docs/marianoguerra/mcp) | TBD | TBD | MCP protocol types + JSON-RPC codec, **planned** |

**Data source attribution:** ecosystem metadata is retrieved from
[mooncakes.io](https://mooncakes.io) public JSON API. This project is not
affiliated with mooncakes.io.

**Ports / references:** if any code is ported or adapted from another project,
the source and license will be stated here and in the file header.

---

## 开发计划与验收线

| 阶段 | 内容 | 状态 |
|---|---|---|
| M0 | 仓库骨架、`moon.mod`、构建与测试跑通、CI | ✅ |
| M1 | mooncakes API 客户端 + fixture 测试 | ✅ |
| M2 | MCP 协议层 + STDIO 传输 + `search_packages` | ✅ |
| M3 | `get_package_api` ✅ ／ `suggest_dependencies` | 🚧 |
| M4 | `pack_project_context`（import 相关性 + 包事实注入） | ⬜ |
| M5 | 本地快照缓存（TTL，断网兜底） | ⬜ |
| M6 | 演示录屏 + 验收材料 | ⬜ |

**9/24 验收线**：四个工具可用、测试通过、README 可让评审独立跑起来、附演示录屏。

**后续（季度）**：语义检索、依赖图查询、发布到 MCP registry、编辑器插件。

---

## AI 使用说明

对应验收标准第 6 条「AI 可解释」。本项目使用 AI 辅助编码，但**目标、架构、技术选型与质量边界由作者把控**：

- **技术选型由人决策**：数据源选用官方 JSON API 而非爬 HTML；缓存选用「快照 + TTL」而非纯实时请求 —— 取舍理由见提交记录与设计文档
- **AI 产出必须可验证**：所有 AI 生成的代码必须通过测试；AI 给出的 API 名称一律以 mooncakes.io 实际返回为准（这也正是本项目的立意）
- **保留完整开发轨迹**：公开仓库保留 commits / Issues / PR，可追溯每个设计决策

---

## 项目文档

- [可复现演示说明](docs/demo.md) —— **三条命令验证项目能跑**（评审先看这个）
- [架构与设计说明](docs/architecture.md) —— **它是什么、怎么实现的、为什么这样设计**（含思维导图）
- [一页项目说明](docs/project-brief.md) —— 报名与评审材料
- [AGENTS.md](AGENTS.md) —— 给 AI 编程代理的项目约定

## 许可证

[Apache-2.0](LICENSE) © 2026 李冠达 (liguanda888)

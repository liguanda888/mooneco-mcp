# MoonEco MCP —— 让 AI 真正读懂 MoonBit 生态

> 2026 MoonBit 九月黑客松 · 一页项目说明
> 仓库：https://github.com/liguanda888/mooneco-mcp ｜ 许可：Apache-2.0

---

## 一、要解决的问题

用 AI 写 MoonBit 时，有两个真实且互相纠缠的痛点：

**痛点 1：AI 不知道生态里有什么。**
MoonBit 生态已有 2000+ 个包，覆盖 Parquet、Protobuf、SQLite、MCP、TUI、Markdown、正则……
但这些都不在大模型的训练数据里。结果就是**幻觉 API** 和**重复造轮子**——AI 会一本正经地编一个不存在的函数名，
或者花 200 行手写一个生态里早就有的东西。

**痛点 2：上下文又贵又乱。**
把整个仓库塞进上下文，既超 token 预算，又信噪比极低。

**这两个问题本质是同一个问题：AI 缺少「正确的上下文」。** 本项目就是这个问题的工具化答案。

---

## 二、项目特色

| 特色 | 说明 |
|---|---|
| **内置生态索引** | 覆盖 mooncakes.io 全量包，按**意图**检索，融合名称匹配、关键词、下载量、维护活跃度加权排序 |
| **零幻觉 API** | 所有 API 名称与依赖关系都来自 mooncakes.io 的真实返回，**不依赖模型记忆** |
| **MoonBit 语义级上下文** | 打包项目上下文时，会把项目**实际用到的包的 API 摘要与依赖关系一并注入**——因为工具理解 MoonBit 的包结构，而不是单纯按文件切分 |
| **离线可复现** | 本地快照缓存 + TTL；测试基于录制的 JSON fixture，不依赖实时网络 |
| **纯 MoonBit 实现** | 无 FFI，全项目 MoonBit |

---

## 三、目标用户与使用场景

**用户**：用 Claude Code、Codex 以及其他 MCP 兼容客户端写 MoonBit 的开发者。

**典型流程**（演示脚本）：
> 开发者对 AI 说："用 MoonBit 解析 Parquet 并写入 SQLite。"

1. AI 调 `suggest_dependencies("解析 Parquet 并写入 SQLite")`
   → 返回 `mizchi/parquet@0.2.1`、`Lfan-ke/moon-sqlite@0.2.2`，含下载量、许可证、依赖表
2. AI 调 `get_package_api("mizchi/parquet", "0.2.1")`
   → 返回 API 摘要与依赖，AI 不再靠猜
3. AI 调 `pack_project_context("./myproject", 32000)`
   → 按 import 相关性排序，把项目压进 32k token 预算，**并附上这些包的真实 API 摘要**
4. AI 基于**真实存在**的包与 API 写代码

---

## 四、交付物：4 个 MCP 工具

| 工具 | 作用 |
|---|---|
| `search_packages(intent, limit)` | 按意图检索生态包，带下载量、许可证与维护活跃度 |
| `get_package_api(name, version)` | 返回指定包的 API 摘要、依赖表、README 要点 |
| `suggest_dependencies(requirement)` | 「我要做 X」→ 反查该用哪些包，并给出替代方案对比 |
| `pack_project_context(path, budget)` | 把项目压进 token 预算，**同时注入所用包的 API 摘要**，让上下文自带生态知识 |

**形态**：一个 MCP Server（STDIO 传输），可在任意支持 MCP 的客户端中一行配置接入。

---

## 五、技术路线

- **主实现语言：MoonBit**（全项目纯 MoonBit，无 FFI，满足验收标准第 1 条）
- **协议**：MCP（Model Context Protocol），STDIO + JSON-RPC 2.0
- **数据源**：mooncakes.io 官方 JSON API（**已实测可用**）
  - `GET /api-new/v0/search?kw=<关键词>&limit=N` → 名称/版本/许可证/仓库/关键词/描述/下载量/匹配片段
  - `GET /api-new/v0/modules/<owner>/<name>` → 含 `deps` 依赖表与 README
- **缓存**：本地快照 + TTL 过期，保证**断网也能复现**（验收标准第 3 条）
- **测试**：单元测试（JSON 解析、排序权重、token 估算）+ 端到端测试（基于**录制的 API fixture**，不依赖实时网络）
- **可复现**：`moon build` → `moon test` → 一行 MCP 配置，三步可复现

**依赖说明**：协议层计划复用社区包 `marianoguerra/mcp`（零依赖，含 JSON-RPC codec 与 MCP 类型）；
若其 API 不满足需求，则自行实现最小 JSON-RPC 2.0 层。两种路线均在 README 的
`Dependencies & Attribution` 小节标注来源与许可证。

---

## 六、9/16–9/24 交付计划

| 日期 | 目标 | 状态 |
|---|---|---|
| 9/16 | 仓库骨架、`moon.mod`、构建与测试跑通、CI | ✅ 已完成 |
| 9/17 | mooncakes API 客户端 + 本地快照缓存 + fixture 测试 | 待做 |
| 9/18 | MCP Server 骨架（`initialize` / `tools/list` / `tools/call`）+ `search_packages` | 待做 |
| 9/19（周六） | `get_package_api` + `suggest_dependencies` | 待做 |
| 9/20 | 排序权重调优 + 边界用例测试 | 待做 |
| 9/21 | `pack_project_context`（import 相关性 + 包 API 注入） | 待做 |
| 9/22 | 端到端测试 + 在 MCP 兼容客户端中实测接入 | 待做 |
| 9/23 | README 完善、可复现演示说明、演示录屏、AI 使用说明 | 待做 |
| 9/24 | 提交验收材料 | 待做 |

**验收线（9/24 必须达到）**：4 个工具可用、测试通过、README 可让评审独立跑起来、演示录屏。

**季度目标（9/25 起，中秋 + 国庆假期）**：语义检索、依赖图查询、发布到 MCP registry、编辑器插件。

---

## 七、AI 使用说明（对应验收标准第 6 条「AI 可解释」）

本项目全程使用 AI 辅助编码，但**目标、架构、技术选型与质量边界由本人把控**，具体体现在：

1. **技术选型由人决策**：数据源选用官方 JSON API 而非爬 HTML；缓存策略选用「快照 + TTL」而非纯实时请求——这些取舍的理由会在 README 与提交记录中说明。
2. **AI 产出必须可验证**：所有 AI 生成的代码都必须通过测试；对 AI 给出的 API 名称，一律以 mooncakes.io 实际返回为准（这也正是本项目的立意）。
3. **保留完整开发轨迹**：公开仓库保留 commits、Issues 与 PR，可追溯每个设计决策的来由。

---

## 八、风险与应对

| 风险 | 应对 |
|---|---|
| mooncakes API 变更或限流 | 本地快照缓存兜底；接口层做适配封装，便于替换 |
| MoonBit 的 STDIN/STDOUT 逐行处理不满足 MCP 需求 | 已有社区证据表明可行；退路是改用 MCP 的 Streamable HTTP 传输 |
| 8 天时间紧（工作日仅晚间） | 范围已按「月度必做 / 季度再扩」切分；优先保证可验收的完整闭环 |
| 依赖第三方包的许可证合规 | README 的 `Dependencies & Attribution` 小节明确标注来源与许可证（验收标准第 5 条） |

---

## 九、开源与成果

- 仓库公开：https://github.com/liguanda888/mooneco-mcp
- 许可证：Apache-2.0（OSI 认证）
- 保留完整开发历史（commits / Issues / PR）
- 项目目标不止于参赛：MoonBit 生态持续增长，**「让 AI 准确理解生态」是一类长期需要的基础设施**

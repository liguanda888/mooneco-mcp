# MoonEco MCP 项目申报书

## 基本信息

- **项目名称**：MoonEco MCP：让 AI 真正读懂 MoonBit 生态
- **参赛者**：李冠达
- **GitHub 仓库链接**：https://github.com/liguanda888/mooneco-mcp
- **项目方向**：语言与开发工具
- **是否为移植项目**：否（原创项目）
- **本项目许可证**：Apache-2.0

## 项目简介

用 AI 写 MoonBit 有两个相互纠缠的痛点。其一，生态已有 2000+ 个包（Parquet、Protobuf、SQLite、MCP、TUI 等），但都不在大模型的训练数据里，AI 会一本正经地编造不存在的 API 名，或者花 200 行手写生态里早就有的东西。其二，把整个仓库塞进上下文，既超 token 预算，信噪比又极低。两者本质相同——AI 缺少「正确的上下文」。MoonEco MCP 是这个问题的工具化答案：一个纯 MoonBit 实现的 MCP Server，让 AI 在动手写代码前先拿到生态中真实存在的包与 API。项目面向使用 Claude Code、Codex 及其他 MCP 兼容客户端编写 MoonBit 的开发者。

## 通用性说明

- **客户端通用**——采用标准 MCP 协议（STDIO + JSON-RPC 2.0），不绑定任何 IDE，任意 MCP 兼容客户端一行配置即可接入；
- **工程通用**——不针对特定仓库，任意 MoonBit 工程均可使用；
- **语义通用**——所有 API 名称与依赖关系均取自 mooncakes.io 的真实返回，不依赖模型记忆，因此不随模型版本变化而失效。

## 预期使用场景

**场景 1 · 从自然语言需求反查依赖。** 开发者对 AI 说「用 MoonBit 解析 Parquet 并写入 SQLite」。AI 调用 `suggest_dependencies`，得到 `mizchi/parquet` 与 `Lfan-ke/moon-sqlite`，含版本、下载量、许可证与替代方案对比；再调用 `get_package_api` 确认 API 摘要后写码——全程不靠猜。

**场景 2 · 接手陌生仓库。** 开发者打开一个已有的 MoonBit 项目，问「这个项目用了哪些包、我该从哪读起」。AI 调用 `pack_project_context("./myproject", 32000)`，工具按 import 相关性排序，把项目压进 32k token 预算，并附上所涉包的真实 API 摘要，让 AI 在预算内获得完整上下文。

**场景 3 · 生态选型与 API 核对。** 开发者想知道「做 MCP server 该选哪个包」，或写码后想核实 AI 给出的函数名是否真实存在。AI 调用 `search_packages("MCP server", 10)`，按意图检索 mooncakes.io 全量包并给出候选列表，作为选型与纠错依据；具体排序信号见「核心功能范围」。

## 核心功能范围

- 提供 `search_packages(intent, limit)`，按意图检索生态包，返回包名、版本、下载量、许可证与发布时间；
- 提供 `get_package_api(name, version)`，返回指定包的 API 摘要、依赖表与 README 要点；
- 提供 `suggest_dependencies(requirement)`，由「我要做 X」反查该用哪些包，并给出替代方案对比；
- 提供 `pack_project_context(path, budget)`，按 import 相关性把项目压进 token 预算，并注入所用包的真实 API 摘要；
- 内置 mooncakes.io 全量包索引，按名称、关键词、描述匹配度与下载量加权排序，并标记新包（`is_new`），保证零幻觉 API；
- 实现 MCP Server 骨架（`initialize` / `tools/list` / `tools/call`），STDIO + JSON-RPC 2.0 传输；
- 提供 mooncakes.io API 客户端与本地快照 + TTL 缓存，保证断网可复现；
- 提供单元测试（JSON 解析、排序权重、token 估算）与基于录制 JSON fixture 的端到端测试；
- 提供 README 示例，覆盖依赖反查、包 API 查询、上下文打包与 MCP 客户端一行接入。

## 原创性说明

- **项目性质：原创项目。** 非移植项目，亦非对某个已有开源项目的改写；项目目标、架构与技术选型均由本人独立设计。
- 第 7 项（参考项目名称、来源链接、许可证）**不适用**——本项目为原创，无移植来源。
- **第三方依赖**：本项目未使用任何第三方 MCP 实现，协议层自行实现，唯一外部依赖是 moonbitlang/async

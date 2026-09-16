# MoonContext MCP

**An MCP server that gives AI coding agents accurate knowledge of the MoonBit ecosystem — and packs project context within a token budget.**

The MoonBit ecosystem has 2000+ packages, but they are not in any model's training data. The result: AI invents non-existent APIs, or re-implements what already exists.

MoonContext MCP hands the agent two things it lacks: **ecosystem knowledge** and **relevant project context**.

> Entry for the **2026 MoonBit September Hackathon**. Licensed under [Apache-2.0](LICENSE).
> 中文说明: [README.md](README.md)

---

## The Problem

| Pain | Symptom | Answer |
|---|---|---|
| The agent doesn't know what exists | Hallucinated APIs, reinvented wheels | `search_packages` / `suggest_dependencies` |
| The agent doesn't know how a package works | Guessed signatures and arguments | `get_package_api` |
| Context is expensive and noisy | Whole repo stuffed into the prompt | `pack_project_context` |

---

## Tools

| Tool | Description |
|---|---|
| `search_packages` | Search ecosystem packages by intent. Weighted ranking over name match, keywords, downloads and maintenance activity |
| `get_package_api` | API summary, dependency table and README highlights for a given package |
| `suggest_dependencies` | "I want to build X" → which packages to use, with alternatives compared |
| `pack_project_context` | Compress a project into a token budget, selecting files by import relevance |

Tool `description` and `inputSchema` fields are written in **English** for best
model compatibility and tool-calling accuracy.

---

## Example

Ask your agent:

> "Parse Parquet and write it into SQLite, in MoonBit."

The agent will:

1. `suggest_dependencies("parse parquet and write to sqlite")`
   → `mizchi/parquet@0.2.1`, `Lfan-ke/moon-sqlite@0.2.2` (with licenses and download counts)
2. `get_package_api("mizchi/parquet", "0.2.1")`
   → real API surface and dependency table, no guessing
3. `pack_project_context("./myproject", 32000)`
   → import-ranked context that fits 32k tokens
4. Write code against packages that **actually exist**.

---

## Tech Stack

- **MoonBit** — pure MoonBit implementation, no FFI
- **MCP (Model Context Protocol)** — STDIO + JSON-RPC 2.0
- **Data source** — mooncakes.io official JSON API
  - `GET https://mooncakes.io/api-new/v0/search?kw=<keyword>&limit=N`
  - `GET https://mooncakes.io/api-new/v0/modules/<owner>/<name>`
- **Local snapshot cache** (TTL) — reproducible even offline

---

## Quick Start

> 🚧 Work in progress. Commands below become available as milestones land.

```bash
# 1. Install the MoonBit toolchain (Windows PowerShell)
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser; irm https://cli.moonbitlang.cn/install/powershell.ps1 | iex

# 2. Build
moon build --target native

# 3. Test
moon test

# 4. Register in your MCP client
#    Point Claude Code / Codex / Cursor at the built executable
```

---

## Status & Roadmap

**Acceptance line (Sep 24):** four tools working, tests passing, README sufficient
for a reviewer to reproduce independently, plus a demo recording.

**Post-acceptance (quarterly):** semantic retrieval, dependency-graph queries,
publishing to the MCP registry, editor integration.

---

## License

[Apache-2.0](LICENSE) © 2026 李冠达 (liguanda888)

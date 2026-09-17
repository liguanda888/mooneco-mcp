# MoonEco MCP

**An MCP server that lets AI coding agents actually understand the MoonBit ecosystem.**

The MoonBit ecosystem has 2000+ packages, but they are not in any model's training data. So agents invent non-existent APIs, or re-implement packages that already exist.

MoonEco MCP lets an agent look up the **real packages and the real APIs** before it writes code, and hands it project context that is **MoonBit-semantic** and fits a token budget.

> Entry for the **2026 MoonBit September Hackathon**. Licensed under [Apache-2.0](LICENSE).
> 中文说明: [README.md](README.md)

---

## What Makes It Different

| Feature | Description |
|---|---|
| 🔍 **Built-in ecosystem index** | Full mooncakes.io coverage, **intent-based** search with weighted ranking over name match, keywords, downloads and maintenance activity |
| 🚫 **Zero-hallucination APIs** | Every API name and dependency edge comes from a real mooncakes.io response — **never from model memory** |
| 🧠 **MoonBit-semantic context** | When packing project context it also injects the **API summaries and dependency edges of the packages the project actually uses**, because the tool understands MoonBit package structure rather than just slicing files |
| 🔌 **Reproducible offline** | Local snapshot cache with TTL; tests run against recorded JSON fixtures, so a reviewer can re-run everything without network |
| 🧩 **Pure MoonBit** | No FFI, 100% MoonBit, multi-backend ready |

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
| `search_packages` | Search packages by intent, with download counts, licenses and maintenance activity |
| `get_package_api` | Verified facts (dependency table, version history, build status, license) **plus the package's own README** — section outline and truncated body |
| `suggest_dependencies` | "I want to build X" → which packages to use, with alternatives compared |
| `pack_project_context` | Compress a project into a token budget, **injecting the dependency and version facts of the packages it uses** |

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
   → real dependency table and version history; since the upstream API exposes no
   function signatures, the tool **fetches the repository README** (section outline
   plus a truncated body) and says so plainly when it cannot
3. `pack_project_context("./myproject", 32000)`
   → fits 32k tokens, with the real dependency and version facts of those packages attached
4. Write code against packages that **actually exist**, using documentation that was **actually read**.

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
#    Point Claude Code, Codex, or any other MCP-compatible client at the built executable
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

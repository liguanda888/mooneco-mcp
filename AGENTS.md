# AGENTS.md — Guide for AI coding agents

This is a [MoonBit](https://docs.moonbitlang.com) project. It is itself a tool
for AI agents, so this file matters more than usual: keep it accurate.

Extra MoonBit skills for agents: <https://github.com/moonbitlang/skills>

## What this project is

`MoonEco MCP` is an MCP (Model Context Protocol) server that lets AI coding
agents actually understand the MoonBit ecosystem.

It has two halves that reinforce each other:

1. **Ecosystem knowledge** — what packages exist on mooncakes.io and what their
   APIs actually look like. Prevents hallucinated APIs and reinvented wheels.
2. **MoonBit-semantic context** — the relevant parts of a MoonBit project, packed
   to fit a token budget, **plus the API summaries of the packages the project
   uses**. The packer understands MoonBit package structure, so it can enrich
   context with real ecosystem facts instead of only slicing files.

Four tools are exposed over MCP: `search_packages`, `get_package_api`,
`suggest_dependencies`, `pack_project_context`.

## Design principles

- **Zero hallucination** — every API name and dependency edge must come from a
  real mooncakes.io response. Never hardcode or guess package facts.
- **Offline reproducible** — all network access is cache-backed, and tests run
  against recorded fixtures. A reviewer must be able to run the full suite with
  no network.
- **Intent-based retrieval, not substring matching** — ranking weighs name match,
  keywords, download counts and maintenance recency.
- **Pure MoonBit, no FFI.**

## Project structure

MoonBit packages are organized per directory. Each directory holds a `moon.pkg`
listing that package's dependencies. Each package has:

- regular files — the implementation
- `*_test.mbt` — blackbox tests (run against the public API, imported as `@packagename`)
- `*_wbtest.mbt` — whitebox tests (run inside the package scope, **no** package prefix)

The root `moon.mod` holds module metadata.

Layout:

```
mooneco.mbt            root package: shared types, public facade
mooncakes/             mooncakes.io API client + local snapshot cache
rank/                  relevance scoring and ranking of search results
context/               MoonBit-semantic context packing (token budget)
mcp/                   MCP protocol layer (JSON-RPC 2.0 over STDIO)
cmd/main/              executable entry point (the MCP server)
```

## Coding convention

- MoonBit code is organized in block style. Each block is separated by `///|`.
  **The order of blocks is irrelevant**, so you can refactor block by block.
- Keep deprecated blocks in a file named `deprecated.mbt` inside each directory.
- Identifiers are English. Comments explain *why*, and key design intent is
  written in Chinese (this is a Chinese-first repository).
- MCP tool `name` / `description` / `inputSchema` fields are **English** — they
  are consumed by models, and English improves tool-calling accuracy.

## Tooling

- `moon fmt` — format the code.
- `moon check` — type-check without producing artifacts.
- `moon build --target native` — build the server binary.
- `moon test` — run tests. `moon test --update` refreshes snapshots.
- `moon info` — regenerate each package's `.mbti` interface file. If a change
  does not alter any `.mbti`, it is a safe internal refactoring.
- `moon coverage analyze > uncovered.log` — find untested code.
- Always finish with `moon info && moon fmt`, and check the `.mbti` diff.

## Testing guidance

- Prefer `assert_eq` or `assert_true(pattern is Pattern(...))` for stable results.
- For structured debug output in snapshot tests, derive `Debug` and use
  `debug_inspect`. Do not derive `Show` just for debugging.
- Tests must not require live network access. The mooncakes.io client is tested
  against **recorded JSON fixtures**.

## Data source

Ecosystem metadata comes from the public mooncakes.io JSON API:

- `GET https://mooncakes.io/api-new/v0/search?kw=<keyword>&limit=N`
- `GET https://mooncakes.io/api-new/v0/modules/<owner>/<name>`

Never scrape HTML. Never invent API shapes — verify against a real response and
record it as a fixture.

## Ground rules

- **No FFI**, pure MoonBit only.
- Do not add a dependency without recording it (with version + license) in the
  `Dependencies & Attribution` section of `README.md`.
- Never write comparisons to, or claims about, other projects into the docs.
  Describe only what this project does.

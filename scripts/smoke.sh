#!/bin/sh
# MCP 端到端冒烟测试。
#
# 把真实的 JSON-RPC 消息喂给已构建的服务器，检查四项协议行为：
#   1. initialize 返回 serverInfo
#   2. 通知（无 id）**不得**回应 —— 这是最容易写错、也最容易被客户端投诉的一点
#   3. tools/list 列出全部四个工具
#   4. 未知方法返回 -32601
#
# 用法：
#   sh scripts/smoke.sh [可执行文件路径]
# 不传路径时自动在 _build 下查找。

set -eu

BIN="${1:-}"
if [ -z "$BIN" ]; then
  for candidate in \
    _build/native/debug/build/cmd/main/main \
    _build/native/debug/build/cmd/main/main.exe
  do
    if [ -x "$candidate" ]; then
      BIN="$candidate"
      break
    fi
  done
fi

if [ -z "$BIN" ]; then
  echo "找不到可执行文件，请先运行： moon build --target native" >&2
  exit 1
fi

OUT="$(mktemp)"
ERR="$(mktemp)"
trap 'rm -f "$OUT" "$ERR"' EXIT

# 4 条输入，其中第 2 条是通知 —— 因此正确的实现只应产生 3 条回应。
printf '%s\n' \
  '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"smoke","version":"0"}}}' \
  '{"jsonrpc":"2.0","method":"notifications/initialized"}' \
  '{"jsonrpc":"2.0","id":2,"method":"tools/list"}' \
  '{"jsonrpc":"2.0","id":3,"method":"nope"}' \
  | "$BIN" >"$OUT" 2>"$ERR"

fail=0
check() {
  if grep -q "$1" "$OUT"; then
    echo "  ok   $2"
  else
    echo "  FAIL $2" >&2
    fail=1
  fi
}

echo "MCP 冒烟测试：$BIN"

lines=$(wc -l <"$OUT" | tr -d ' ')
if [ "$lines" = "3" ]; then
  echo "  ok   收到 3 条回应（通知未被回应）"
else
  echo "  FAIL 期望 3 条回应，实际 $lines 条 —— 通知可能被错误地回应了" >&2
  fail=1
fi

check '"name":"mooneco-mcp"'          'initialize 返回 serverInfo'
check '"search_packages"'             'tools/list 含 search_packages'
check '"get_package_api"'             'tools/list 含 get_package_api'
check '"suggest_dependencies"'        'tools/list 含 suggest_dependencies'
check '"pack_project_context"'        'tools/list 含 pack_project_context'
check '\-32601'                       '未知方法返回 -32601'

# stdout 必须只含协议消息：任何日志都会污染协议流。
if [ -s "$ERR" ]; then
  echo "  note stderr 非空（不影响协议，但请确认那是日志而非错误）" >&2
fi

if [ "$fail" = "0" ]; then
  echo "全部通过"
else
  echo "存在失败项" >&2
  exit 1
fi

#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AGENT_DIR="${HERMES_CONTEXT_TRACE_AGENT_DIR:-$ROOT_DIR/../hermes-agent-capui}"
WEBUI_DIR="$ROOT_DIR"

if [[ ! -d "$AGENT_DIR" ]]; then
  echo "error: missing agent worktree at $AGENT_DIR" >&2
  exit 1
fi

SANDBOX_ROOT="${HERMES_CONTEXT_TRACE_DIR:-$(mktemp -d -t hermes-context-trace.XXXXXX)}"
HERMES_HOME="${HERMES_HOME:-$SANDBOX_ROOT/hermes-home}"
HERMES_WEBUI_STATE_DIR="${HERMES_WEBUI_STATE_DIR:-$SANDBOX_ROOT/webui-state}"
LOG_DIR="$SANDBOX_ROOT/logs"
AGENT_LOG="$LOG_DIR/agent.log"
WEBUI_LOG="$LOG_DIR/webui.log"
SEED_DIR="${HERMES_CONTEXT_TRACE_FROM:-${HOME}/.hermes}"

mkdir -p "$HERMES_HOME" "$HERMES_WEBUI_STATE_DIR" "$LOG_DIR"

if [[ -d "$SEED_DIR" ]] && [[ -z "$(ls -A "$HERMES_HOME" 2>/dev/null)" ]]; then
  cp -a "$SEED_DIR/." "$HERMES_HOME/" 2>/dev/null || true
fi

export HERMES_HOME
export HERMES_WEBUI_STATE_DIR
export HERMES_WEBUI_AGENT_DIR="$AGENT_DIR"
export HERMES_WEBUI_CHAT_BACKEND="${HERMES_WEBUI_CHAT_BACKEND:-gateway}"
export HERMES_WEBUI_GATEWAY_BASE_URL="${HERMES_WEBUI_GATEWAY_BASE_URL:-http://127.0.0.1:8642}"
export HERMES_WEBUI_HOST="${HERMES_WEBUI_HOST:-127.0.0.1}"
export HERMES_WEBUI_PORT="${HERMES_WEBUI_PORT:-8787}"
export HERMES_WEBUI_PRESERVE_ENV=1

cleanup() {
  local rc=$?
  if [[ -n "${WEBUI_PID:-}" ]] && kill -0 "$WEBUI_PID" 2>/dev/null; then
    kill "$WEBUI_PID" 2>/dev/null || true
  fi
  if [[ -n "${AGENT_PID:-}" ]] && kill -0 "$AGENT_PID" 2>/dev/null; then
    kill "$AGENT_PID" 2>/dev/null || true
  fi
  wait "${WEBUI_PID:-}" 2>/dev/null || true
  wait "${AGENT_PID:-}" 2>/dev/null || true
  echo
  echo "sandbox: $SANDBOX_ROOT"
  echo "agent log: $AGENT_LOG"
  echo "webui log: $WEBUI_LOG"
  exit "$rc"
}
trap cleanup EXIT INT TERM

(
  cd "$AGENT_DIR"
  ./scripts/hermes-gateway run
) >"$AGENT_LOG" 2>&1 &
AGENT_PID=$!

for _ in {1..30}; do
  if curl -fsS "${HERMES_WEBUI_GATEWAY_BASE_URL%/}/health" >/dev/null 2>&1; then
    break
  fi
  sleep 1
done

(
  cd "$WEBUI_DIR"
  python3 bootstrap.py --no-browser
) >"$WEBUI_LOG" 2>&1 &
WEBUI_PID=$!

echo "sandbox: $SANDBOX_ROOT"
echo "agent log: $AGENT_LOG"
echo "webui log: $WEBUI_LOG"
echo "WebUI: http://127.0.0.1:8787"
echo "Agent gateway: http://127.0.0.1:8642"
echo
echo "Tail both logs with:"
echo "  tail -f '$AGENT_LOG' '$WEBUI_LOG'"
echo
echo "Use /context all in the agent to inspect live context composition."
echo "WebUI outbound payload logs appear as [webui-debug] lines."

tail -f "$AGENT_LOG" "$WEBUI_LOG"

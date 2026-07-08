#!/bin/sh
# Otty — Kimi Code CLI hook.
#
# Reports the agent's state to the Otty app over IPC so a terminal pane can
# show the processing / idle / awaiting-input badge. Otty registers this script
# in ~/.kimi-code/config.toml (Settings → Agents → Install Hooks). It is shipped
# as a readable, code-signed file inside Otty.app so you can audit exactly what
# runs on every Kimi hook event — Otty injects only the per-install paths.
#
# Args:
#   $1  state    — processing | idle | awaiting
#   $2  kimi_pid — the Kimi process's pid (its $PPID at hook time), so Otty
#                  can match the event to the right pane when several Kimi
#                  instances share a cwd
#   $3  "ctx"    — present only for PermissionRequest: forward the full hook
#                  stdin (base64) so Otty can offer auto-approve context
# Env:
#   OTTY_CLI    — absolute path to the bundled otty-cli (injected by Otty)
#   OTTY_SOCKET — Otty IPC socket path (injected by Otty; read by otty-cli)
state="$1"
kimi_pid="$2"
want_ctx="$3"

# Kimi passes the hook payload as JSON on stdin.
input=$(cat)

# session_id is at the top level of the Kimi hook payload.
sid=$(printf '%s' "$input" | sed -n 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)

# No session id → nothing Otty can match; skip quietly.
[ -n "$sid" ] || exit 0

# cwd lets Otty match the hook to a pane on first sight (esp. SessionStart,
# before any cached mapping exists).
cwd=$(printf '%s' "$input" | sed -n 's/.*"cwd"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)

# Suppress the spurious "task complete" that fires per Agent subagent. An Agent
# subagent runs in the background: while it works, the main agent often yields
# and Kimi fires a Stop (this hook's state=idle) even though the turn isn't
# really over — the still-running subagent may still be active. Treat such a
# Stop as still-processing so the notification only fires on the genuine final
# Stop. Whitespace is stripped so the match survives pretty-printed JSON; both
# key orderings are covered.
# When Kimi fires a tool that waits for user input (AskUserQuestion for
# structured Q&A, ExitPlanMode for plan approval), treat the state as
# awaiting rather than processing so Otty shows the input badge.
if [ "$state" = processing ]; then
    case "$input" in
        *"AskUserQuestion"*|*"ExitPlanMode"*)
            state=awaiting ;;
    esac
fi

# When the agent reports idle/awaiting but a subagent is still running, treat
# the state as still-processing so the completion badge/notification only fires
# on the genuine final Stop.
if [ "$state" = idle ] || [ "$state" = awaiting ]; then
    bt=$(printf '%s' "$input" | tr -d ' \t\n')
    case "$bt" in
        *'"type":"subagent","status":"running"'*|*'"status":"running","type":"subagent"'*)
            state=processing ;;
    esac
fi

# Otty injects OTTY_CLI; the fallback locates otty-cli relative to this script
# inside the bundle (…/Contents/Resources/agent-integration/kimi → …/MacOS).
cli="${OTTY_CLI:-$(CDPATH= cd -- "$(dirname -- "$0")/../../../MacOS" 2>/dev/null && pwd)/otty-cli}"

# OTTY_SOCKET is already in this script's environment (Otty prefixes it on the
# hook command), so otty-cli inherits it. Backgrounded; errors swallowed so a
# missing Otty app never breaks the user's Kimi session.
if [ "$want_ctx" = "ctx" ]; then
    ctx=$(printf '%s' "$input" | base64)
    "$cli" state:kimi session-id="$sid" state="$state" cwd="$cwd" agent-pid="$kimi_pid" context-b64="$ctx" 2>/dev/null &
else
    "$cli" state:kimi session-id="$sid" state="$state" cwd="$cwd" agent-pid="$kimi_pid" 2>/dev/null &
fi

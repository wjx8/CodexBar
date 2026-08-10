#!/bin/zsh
set -euo pipefail

APP_BUNDLE="${1:-}"
APP_NAME="CodexBar"
LOCK_FILE="$HOME/Library/Application Support/CodexBar/manual-quit.lock"

if [[ -z "$APP_BUNDLE" || ! -d "$APP_BUNDLE" ]]; then
    exit 0
fi

codex_host_is_running() {
    /usr/bin/pgrep -x "Codex" >/dev/null 2>&1 ||
        /usr/bin/pgrep -x "ChatGPT" >/dev/null 2>&1 ||
        /usr/bin/pgrep -x "GPT" >/dev/null 2>&1
}

if ! codex_host_is_running; then
    /bin/rm -f "$LOCK_FILE" >/dev/null 2>&1 || true
    exit 0
fi

if [[ -f "$LOCK_FILE" ]]; then
    exit 0
fi

if /usr/bin/pgrep -x "$APP_NAME" >/dev/null 2>&1; then
    exit 0
fi

/usr/bin/open "$APP_BUNDLE" >/dev/null 2>&1 || true

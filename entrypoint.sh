#!/usr/bin/env bash
set -euo pipefail

ensure_runtime_dirs() {
  mkdir -p \
    "$HOME/workspace" \
    "$XDG_CONFIG_HOME/opencode" \
    "$XDG_DATA_HOME/opencode" \
    "$XDG_STATE_HOME/opencode" \
    "$XDG_CACHE_HOME/opencode" \
    "$UV_CACHE_DIR" \
    "$UV_PYTHON_INSTALL_DIR"
}

mark_git_safe_dirs() {
  if command -v git >/dev/null 2>&1; then
    git config --global --add safe.directory "$PWD" >/dev/null 2>&1 || true
    if [ -d "$HOME/workspace" ]; then
      git config --global --add safe.directory "$HOME/workspace" >/dev/null 2>&1 || true
    fi
  fi
}

main() {
  ensure_runtime_dirs
  mark_git_safe_dirs

  if [ "$#" -eq 0 ]; then
    exec opencode
  fi

  case "$1" in
    opencode)
      exec "$@"
      ;;
    bash|sh|sleep|tail|env|uv|uvx|python3|pip3|go|docker|node)
      exec "$@"
      ;;
    -*)
      exec opencode "$@"
      ;;
    *)
      exec opencode "$@"
      ;;
  esac
}

main "$@"

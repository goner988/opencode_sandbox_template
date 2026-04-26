#!/usr/bin/env bash
# Shared environment for interactive and non-interactive bash shells.

export NPM_CONFIG_PREFIX=/usr/local/share/npm-global
export PATH=/home/agent/.local/bin:/usr/local/share/npm-global/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

export XDG_CONFIG_HOME=/home/agent/.config
export XDG_DATA_HOME=/home/agent/.local/share
export XDG_STATE_HOME=/home/agent/.local/state
export XDG_CACHE_HOME=/home/agent/.cache
export OPENCODE_CONFIG_DIR=/home/agent/.config/opencode

export UV_TOOL_BIN_DIR=/home/agent/.local/bin
export UV_CACHE_DIR=/home/agent/.cache/uv
export UV_PYTHON_INSTALL_DIR=/home/agent/.local/share/uv/python
export UV_LINK_MODE=copy

umask 022

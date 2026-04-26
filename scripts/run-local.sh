#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME="${IMAGE_NAME:-local/sandbox-opencode-local}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
WORKSPACE="${1:-$PWD}"
shift || true

exec docker run -it --rm \
  -v "${WORKSPACE}:/home/agent/workspace" \
  -w /home/agent/workspace \
  "${IMAGE_NAME}:${IMAGE_TAG}" "$@"

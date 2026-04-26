#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME="${IMAGE_NAME:-local/sandbox-opencode-local}"
PLATFORM="${PLATFORM:-linux/arm64}"

source ./docker/configs/versions.env

# Determine if we are building base or serena variant
BUILD_ARGS=(
  --build-arg "UV_VERSION=${UV_VERSION:-}"
  --build-arg "NODE_VERSION=${NODE_VERSION:-}"
  --build-arg "BUN_VERSION=${BUN_VERSION:-}"
  --build-arg "OPENCODE_VERSION=${OPENCODE_VERSION:-}"
)

if [ -n "${SERENA_VERSION:-}" ]; then
  IMAGE_TAG="serena"
  BUILD_ARGS+=(--build-arg "SERENA_VERSION=${SERENA_VERSION}")
else
  IMAGE_TAG="base"
fi

echo "Building variant: ${IMAGE_TAG}"

exec docker buildx build --load \
  --platform "${PLATFORM}" \
  "${BUILD_ARGS[@]}" \
  -t "${IMAGE_NAME}:${IMAGE_TAG}" \
  .

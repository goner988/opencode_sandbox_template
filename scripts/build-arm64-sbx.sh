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

FULL_IMAGE_NAME="${IMAGE_NAME}:${IMAGE_TAG}"
TAR_FILE="sbx-template-${IMAGE_TAG}.tar"

echo "Building variant: ${IMAGE_TAG} via Docker..."

# 1. Build the image
docker buildx build --load \
  --platform "${PLATFORM}" \
  "${BUILD_ARGS[@]}" \
  -t "${FULL_IMAGE_NAME}" \
  .

# 2. Export from Docker and load into Docker sbx
echo "Exporting image from Docker Desktop to ${TAR_FILE}..."
docker image save "${FULL_IMAGE_NAME}" -o "${TAR_FILE}"

echo "Loading image into Docker sbx environment..."
sbx template load "${TAR_FILE}"

# 3. Clean up tarball
echo "Cleaning up temporary tar file..."
rm "${TAR_FILE}"

echo "Success! The custom image is ready in sbx."
echo "Create a new sbx instance with: sbx create --name NAME_FOR_YOUR_SBX --template ${FULL_IMAGE_NAME}"

#!/usr/bin/env bash
# 在 NAS 上直接构建并替换 subconverter 容器（无需本机 Docker）
# 前提：NAS 已安装 Container Station，且本机可 ssh 到 NAS（BatchMode 或已配密钥）
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
NAS_HOST="${NAS_HOST:-nas-qnap}"
DOCKER_REMOTE="${DOCKER_REMOTE:-/share/CACHEDEV1_DATA/.qpkg/container-station/bin/docker}"
REMOTE_DIR="${REMOTE_DIR:-/share/CACHEDEV1_DATA/Containers/subconverter-build}"
IMAGE="${IMAGE:-subconverter:nas-amd64}"
BASE_IMAGE="${BASE_IMAGE:-subconverter-extended-build}"
CONTAINER="${CONTAINER:-subconverter}"
PORT="${PORT:-25500}"
VERSION="${VERSION:-1.1.18+houjia.6}"
BUILD_SHA="${BUILD_SHA:-$(git -C "$ROOT" rev-parse --short HEAD)}"
BUILD_DATE="${BUILD_DATE:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}"

echo "==> rsync source to $NAS_HOST:$REMOTE_DIR"
ssh -o BatchMode=yes "$NAS_HOST" "mkdir -p '$REMOTE_DIR'"
rsync -az --delete \
  --exclude '.git' --exclude 'subapi-*.png' --exclude 'subw-*.png' --exclude '.DS_Store' \
  "$ROOT/" "$NAS_HOST:$REMOTE_DIR/"

echo "==> build on NAS (native linux/amd64, DOCKER_BUILDKIT=0 规避 QNAP buildx 目录权限)"
ssh -o BatchMode=yes "$NAS_HOST" "cd '$REMOTE_DIR' && \
  DOCKER_BUILDKIT=0 $DOCKER_REMOTE build -f Dockerfile \
    --build-arg VERSION='$VERSION' \
    --build-arg SHA='$BUILD_SHA' \
    --build-arg BUILD_DATE='$BUILD_DATE' \
    -t '$BASE_IMAGE' . && \
  $DOCKER_REMOTE build -f deploy/nas/Dockerfile \
    --build-arg BASE_IMAGE='$BASE_IMAGE' \
    -t '$IMAGE' ."

echo "==> recreate container $CONTAINER"
ssh -o BatchMode=yes "$NAS_HOST" "$DOCKER_REMOTE stop $CONTAINER 2>/dev/null || true; \
  $DOCKER_REMOTE rm $CONTAINER 2>/dev/null || true; \
  $DOCKER_REMOTE run -d --name $CONTAINER --restart always -p ${PORT}:${PORT} $IMAGE"

echo "==> verify"
sleep 3
ssh -o BatchMode=yes "$NAS_HOST" "curl -sS http://127.0.0.1:${PORT}/version.txt | head -1" || true

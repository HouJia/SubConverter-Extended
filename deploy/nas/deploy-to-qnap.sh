#!/usr/bin/env bash
# 构建 linux/amd64 镜像并导入 nas-qnap，替换 subconverter 容器
#
# 两种方式（二选一）：
#   A) 本脚本（默认）— 在本机 Docker 交叉构建后 save/load 到 NAS
#      需要：本机 Docker Desktop 已启动
#   B) deploy-build-on-qnap.sh — 在 NAS 上 rsync 源码并构建
#      需要：NAS Container Station 可用，无需本机 Docker
#
# 用法：./deploy/nas/deploy-to-qnap.sh
#       ./deploy/nas/deploy-build-on-qnap.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
IMAGE="${IMAGE:-subconverter:nas-amd64}"
BASE_IMAGE="${BASE_IMAGE:-subconverter-extended-build}"
NAS_HOST="${NAS_HOST:-nas-qnap}"
DOCKER_REMOTE="${DOCKER_REMOTE:-/share/CACHEDEV1_DATA/.qpkg/container-station/bin/docker}"
CONTAINER="${CONTAINER:-subconverter}"
PORT="${PORT:-25500}"
# Extended 最近 release 为 v1.1.9；主线基于其 master（较 tag 更新）。fork 版本用 SemVer 构建元数据 +houjia.N
VERSION="${VERSION:-1.1.9+houjia.3}"
BUILD_SHA="${BUILD_SHA:-$(git rev-parse --short HEAD)}"
BUILD_DATE="${BUILD_DATE:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}"

cd "$ROOT"
echo "==> stage1: Extended build $BASE_IMAGE (linux/amd64) version=$VERSION"
docker buildx build --platform linux/amd64 -f Dockerfile \
  --build-arg VERSION="$VERSION" \
  --build-arg SHA="$BUILD_SHA" \
  --build-arg BUILD_DATE="$BUILD_DATE" \
  -t "$BASE_IMAGE" --load .

echo "==> stage2: NAS overlay $IMAGE"
docker buildx build --platform linux/amd64 \
  -f deploy/nas/Dockerfile \
  --build-arg BASE_IMAGE="$BASE_IMAGE" \
  -t "$IMAGE" --load .

echo "==> save & load on $NAS_HOST"
docker save "$IMAGE" | ssh -o BatchMode=yes "$NAS_HOST" "$DOCKER_REMOTE load"

echo "==> recreate container $CONTAINER"
ssh -o BatchMode=yes "$NAS_HOST" "$DOCKER_REMOTE stop $CONTAINER 2>/dev/null || true; \
  $DOCKER_REMOTE rm $CONTAINER 2>/dev/null || true; \
  $DOCKER_REMOTE run -d --name $CONTAINER --restart always -p ${PORT}:${PORT} $IMAGE"

echo "==> verify"
sleep 3
ssh -o BatchMode=yes "$NAS_HOST" "curl -sS http://127.0.0.1:${PORT}/version.txt | head -1" || true
ssh -o BatchMode=yes "$NAS_HOST" "$DOCKER_REMOTE exec $CONTAINER grep max_allowed_rulesets /base/pref.toml"

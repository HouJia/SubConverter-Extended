#!/usr/bin/env bash
# 在本机（Mac/Linux）构建 linux/amd64 镜像并导入 nas-qnap，替换 subconverter 容器
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
IMAGE="${IMAGE:-subconverter:nas-amd64}"
NAS_HOST="${NAS_HOST:-nas-qnap}"
DOCKER_REMOTE="${DOCKER_REMOTE:-/share/CACHEDEV1_DATA/.qpkg/container-station/bin/docker}"
CONTAINER="${CONTAINER:-subconverter}"
PORT="${PORT:-25500}"

cd "$ROOT"
echo "==> build $IMAGE (linux/amd64)"
docker buildx build --platform linux/amd64 -f deploy/nas/Dockerfile -t "$IMAGE" --load .

echo "==> save & load on $NAS_HOST"
docker save "$IMAGE" | ssh -o BatchMode=yes "$NAS_HOST" "$DOCKER_REMOTE load"

echo "==> recreate container $CONTAINER"
ssh -o BatchMode=yes "$NAS_HOST" "$DOCKER_REMOTE stop $CONTAINER 2>/dev/null || true; \
  $DOCKER_REMOTE rm $CONTAINER 2>/dev/null || true; \
  $DOCKER_REMOTE run -d --name $CONTAINER --restart always -p ${PORT}:${PORT} $IMAGE"

echo "==> verify"
sleep 2
curl -sS "http://192.168.1.100:${PORT}/version" || true
ssh -o BatchMode=yes "$NAS_HOST" "$DOCKER_REMOTE exec $CONTAINER grep max_allowed_rulesets /base/pref.toml"

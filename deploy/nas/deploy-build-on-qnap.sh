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
VERSION="${VERSION:-1.1.18+houjia.12}"
BUILD_SHA="${BUILD_SHA:-$(git -C "$ROOT" rev-parse --short HEAD)}"
BUILD_DATE="${BUILD_DATE:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}"

PREF_SRC="$ROOT/deploy/nas/pref.toml"
PREF_BUILD="$ROOT/deploy/nas/pref.build.toml"
cp "$PREF_SRC" "$PREF_BUILD"
if [[ -n "${DASHBOARD_AUTH_PASSWORD:-}" ]]; then
  python3 - "$PREF_BUILD" <<'PY'
import pathlib, re, sys
path = pathlib.Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
block = re.compile(
    r"(\[statistics\.dashboard_auth\][\s\S]*?^password = ).*$",
    re.MULTILINE,
)
new_text, n = block.subn(r'\1"' + __import__("os").environ["DASHBOARD_AUTH_PASSWORD"].replace("\\", "\\\\").replace('"', '\\"') + '"', text, count=1)
if n != 1:
    raise SystemExit("pref.build.toml: 未找到 [statistics.dashboard_auth] password 行")
path.write_text(new_text, encoding="utf-8")
PY
elif grep -q '^\[statistics\.dashboard_auth\]' "$PREF_SRC" && grep -A5 '^\[statistics\.dashboard_auth\]' "$PREF_SRC" | grep -q 'enabled = true'; then
  if grep -A8 '^\[statistics\.dashboard_auth\]' "$PREF_BUILD" | grep -q 'password = "CHANGE_ME"'; then
    echo "ERROR: dashboard_auth 已启用但未设置 DASHBOARD_AUTH_PASSWORD" >&2
    exit 1
  fi
fi

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
  $DOCKER_REMOTE run -d --name $CONTAINER --restart always \
    --dns 223.5.5.5 --dns 119.29.29.29 \
    -p ${PORT}:${PORT} $IMAGE"

echo "==> verify"
sleep 3
ssh -o BatchMode=yes "$NAS_HOST" "curl -sS http://127.0.0.1:${PORT}/version.txt | head -1" || true

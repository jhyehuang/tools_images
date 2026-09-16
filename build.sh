#!/usr/bin/env bash
# 构建镜像。默认跟随本机架构；服务器上出 x86：
#   TARGET_PLATFORM=linux/amd64 ./build.sh
#
# 可选环境变量（不设就用 Dockerfile 里的默认值）：
#   TARGET_PLATFORM   构建架构，默认 linux/arm64
#   IMAGE             镜像名，默认 pytools:3.12
#   PIP_INDEX_URL     pip 源
#   DEBIAN_MIRROR     apt 源，如 mirrors.tuna.tsinghua.edu.cn
#   JMETER_VERSION    JMeter 版本，默认 5.6.3
set -euo pipefail
cd "$(dirname "$0")"

TARGET_PLATFORM="${TARGET_PLATFORM:-linux/arm64}"
IMAGE="${IMAGE:-pytools:3.12}"

# 只在显式设置时透传，默认值统一由 Dockerfile 定义，避免两边改不同步
ARGS=()
[ -n "${PIP_INDEX_URL:-}" ]    && ARGS+=(--build-arg "PIP_INDEX_URL=$PIP_INDEX_URL")
[ -n "${DEBIAN_MIRROR:-}" ]    && ARGS+=(--build-arg "DEBIAN_MIRROR=$DEBIAN_MIRROR")
[ -n "${JMETER_VERSION:-}" ]   && ARGS+=(--build-arg "JMETER_VERSION=$JMETER_VERSION")

echo ">>> building $IMAGE for $TARGET_PLATFORM ${ARGS[*]:-}"
docker build \
  --platform "$TARGET_PLATFORM" \
  "${ARGS[@]}" \
  -t "$IMAGE" \
  .

echo ">>> done: $IMAGE"
docker images "$IMAGE"

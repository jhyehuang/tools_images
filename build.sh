#!/usr/bin/env bash
# 构建镜像。默认跟随本机架构；服务器上出 x86：
#   TARGET_PLATFORM=linux/amd64 ./build.sh
#
# 下载源默认已走国内镜像（apt 阿里云 / pip 清华 / JMeter 清华 / maven 阿里云），
# 不需要额外设置。显式设置下面任一变量才会透传给 Dockerfile：
#   APT_MIRROR             apt 源主机名，官方是 deb.debian.org
#   PIP_INDEX_URL          pip 源，官方是 https://pypi.org/simple
#   JMETER_MIRROR          JMeter 下载目录，官方是 https://dlcdn.apache.org/jmeter/binaries
#   MAVEN_MIRROR           maven 仓库，官方是 https://repo1.maven.org/maven2
#   MC_MIRROR / AWS_MIRROR mc、awscli 没有公开国内镜像，内网代理可指过去
#   JMETER_VERSION / JMETER_PLUGINS_MANAGER
#   TARGET_PLATFORM        构建架构，默认 linux/arm64
#   IMAGE                  镜像名，默认 pytools:3.12
set -euo pipefail
cd "$(dirname "$0")"

TARGET_PLATFORM="${TARGET_PLATFORM:-linux/arm64}"
IMAGE="${IMAGE:-pytools:3.12}"

# 显式设置才透传，默认值统一由 Dockerfile 定义，避免两边改不同步
ARGS=()
for v in APT_MIRROR PIP_INDEX_URL JMETER_MIRROR MAVEN_MIRROR MC_MIRROR AWS_MIRROR \
         JMETER_VERSION JMETER_PLUGINS_MANAGER; do
  if [ -n "${!v:-}" ]; then ARGS+=(--build-arg "$v=${!v}"); fi
done

echo ">>> building $IMAGE for $TARGET_PLATFORM ${ARGS[*]:-}"
docker build \
  --platform "$TARGET_PLATFORM" \
  "${ARGS[@]}" \
  -t "$IMAGE" \
  .

echo ">>> done: $IMAGE"
docker images "$IMAGE"

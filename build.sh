#!/usr/bin/env bash
# 构建镜像。不传 TARGET_PLATFORM 时跟随构建机架构
# （本机 M 芯片就是 arm64，x86 服务器就是 amd64，两边都不用管）。
# 只有交叉构建才需要显式指定，例如在 x86 服务器上出 arm64 镜像：
#   TARGET_PLATFORM=linux/arm64 ./build.sh
#
# 下载源默认已走国内源（apt 阿里云 / pip 清华 / JMeter 清华 / maven 阿里云 /
# mc 官方中国 CDN），不需要额外设置。显式设置下面任一变量才会透传给 Dockerfile：
#   APT_MIRROR             apt 源主机名，官方是 deb.debian.org
#   PIP_INDEX_URL          pip 源，官方是 https://pypi.org/simple
#   JMETER_MIRROR          JMeter 下载目录，官方是 https://dlcdn.apache.org/jmeter/binaries
#   MAVEN_MIRROR           maven 仓库，官方是 https://repo1.maven.org/maven2
#   MC_MIRROR / AWS_MIRROR mc、awscli 的内网代理可指过去
#   JMETER_VERSION / JMETER_PLUGINS_MANAGER
#   TARGET_PLATFORM        构建架构，不设 = 跟随构建机
#   IMAGE                  镜像名，默认 pytools:3.12
set -euo pipefail
cd "$(dirname "$0")"

IMAGE="${IMAGE:-pytools:3.12}"

ARGS=()
for v in APT_MIRROR PIP_INDEX_URL JMETER_MIRROR MAVEN_MIRROR MC_MIRROR AWS_MIRROR \
         JMETER_VERSION JMETER_PLUGINS_MANAGER; do
  if [ -n "${!v:-}" ]; then ARGS+=(--build-arg "$v=${!v}"); fi
done

# 只有显式指定才传 --platform，否则用 docker 默认（构建机架构）
PLATFORM_ARGS=()
if [ -n "${TARGET_PLATFORM:-}" ]; then PLATFORM_ARGS=(--platform "$TARGET_PLATFORM"); fi

echo ">>> building $IMAGE ${TARGET_PLATFORM:+(platform=$TARGET_PLATFORM)} ${ARGS[*]:-}"
docker build \
  ${PLATFORM_ARGS[@]+"${PLATFORM_ARGS[@]}"} \
  ${ARGS[@]+"${ARGS[@]}"} \
  -t "$IMAGE" \
  .

echo ">>> done: $IMAGE"
docker images "$IMAGE"

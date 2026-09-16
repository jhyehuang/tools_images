#!/usr/bin/env bash
# 起一个容器，把宿主 data 目录挂到 /data。
# 换目录：HOST_DATA_DIR=/path/to/dir ./run.sh
# 跑别的命令：./run.sh python3 -c 'print(1)'
#
# 不传 TARGET_PLATFORM，直接用本地镜像的架构 —— 别默认写死某个架构，
# 否则在架构不一致的机器上会匹配不到本地镜像，转而去 registry 拉。
set -euo pipefail
cd "$(dirname "$0")"

IMAGE="${IMAGE:-pytools:3.12}"
HOST_DATA_DIR="${HOST_DATA_DIR:-$PWD/data}"

mkdir -p "$HOST_DATA_DIR"

PLATFORM_ARGS=()
if [ -n "${TARGET_PLATFORM:-}" ]; then PLATFORM_ARGS=(--platform "$TARGET_PLATFORM"); fi

exec docker run --rm -it \
  ${PLATFORM_ARGS[@]+"${PLATFORM_ARGS[@]}"} \
  -v "$HOST_DATA_DIR":/data \
  -e TZ=Asia/Shanghai \
  -e DATA_DIR=/data \
  -w /work \
  --name pytools \
  "$IMAGE" \
  "${@:-bash}"

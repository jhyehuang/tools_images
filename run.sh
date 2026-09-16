#!/usr/bin/env bash
# 起一个容器，把宿主 data 目录挂到 /data。
# 换目录：HOST_DATA_DIR=/path/to/dir ./run.sh
set -euo pipefail
cd "$(dirname "$0")"

IMAGE="${IMAGE:-pytools:3.12}"
HOST_DATA_DIR="${HOST_DATA_DIR:-$PWD/data}"

mkdir -p "$HOST_DATA_DIR"

exec docker run --rm -it \
  --platform "${TARGET_PLATFORM:-linux/arm64}" \
  -v "$HOST_DATA_DIR":/data \
  -e TZ=Asia/Shanghai \
  -e DATA_DIR=/data \
  -w /work \
  --name pytools \
  "$IMAGE" \
  "${@:-bash}"

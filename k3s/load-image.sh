#!/usr/bin/env bash
# 把镜像导入 k3s 的 containerd。
# k3s 不认 docker daemon，docker build / docker load 出来的镜像它看不见，
# 必须走 ctr images import，或者推到 registry 让 k3s 自己拉。
#
# 在 k3s 节点上跑（需要 sudo）。镜像 tar 已经传上来的话跳过 save 那步。
set -euo pipefail
cd "$(dirname "$0")"

IMAGE="${IMAGE:-pytools:3.12}"
TAR="${TAR:-pytools-3.12.tar}"

if command -v docker >/dev/null 2>&1 && docker image inspect "$IMAGE" >/dev/null 2>&1; then
  echo ">>> docker save $IMAGE -> $TAR"
  docker save "$IMAGE" -o "$TAR"
else
  echo ">>> 本机没有 docker 镜像，直接用现成的 $TAR"
fi

echo ">>> k3s ctr images import $TAR"
# --all-platforms: buildx 产出的 tar 带 manifest list，不加这个只导当前架构
sudo k3s ctr images import --all-platforms "$TAR"

echo ">>> 已导入："
sudo k3s ctr images ls | grep -i pytools || true

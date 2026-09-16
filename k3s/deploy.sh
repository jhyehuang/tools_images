#!/usr/bin/env bash
# 部署 / 更新 k3s 上的 pytools Pod，然后 exec 进去。
# 别在 k3s 节点上跑 kubectl 之外的操作时忘了先跑 ./load-image.sh。
set -euo pipefail
cd "$(dirname "$0")"

echo ">>> apply"
kubectl apply -f pytools.yaml

echo ">>> 等待就绪"
kubectl -n pytools rollout status deploy/pytools --timeout=120s

kubectl -n pytools get pods -l app=pytools -o wide

cat <<'EOF'

>>> 进容器：
    kubectl -n pytools exec -it deploy/pytools -- bash
>>> 看挂载是否生效：
    kubectl -n pytools exec deploy/pytools -- ls -la /data
>>> 换宿主目录后要重新 apply（hostPath 在 Pod 规格里，改了必须重建 Pod）：
    kubectl -n pytools rollout restart deploy/pytools
EOF

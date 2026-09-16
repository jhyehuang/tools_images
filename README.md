# tools_images

带常用运维/数据工具的 Python 3.12 镜像，用于本地跑脚本。

## 文件

| 文件 | 作用 |
| --- | --- |
| `Dockerfile` | 镜像定义 |
| `requirements.txt` | Python 依赖，按需增删 |
| `build.sh` | 构建镜像 |
| `run.sh` | 起容器并挂载宿主目录 |
| `docker-compose.yml` | compose 方式构建/运行 |
| `k3s/` | k3s 上部署的 manifest 和脚本，见下文 |
| `data/` | 默认挂载进容器的宿主目录 |

## 镜像里有什么

- **Python** 3.12 (slim-bookworm) + `requirements.txt` 里的库(requests / boto3 / minio / pandas / openpyxl …)
- **对象存储**：MinIO `mc`、AWS CLI v2
- **压测**：Apache JMeter 5.6.3（含 JRE 17、jmeter-plugins-manager）
- **常用命令**：git、vim、jq、tree、rsync、curl/wget、less、procps/ps、lsof、ip/ping/dig/nc/telnet、unzip/zip、tar/gzip
- 时区固定 `Asia/Shanghai`

## 用法

Docker Desktop 要先启动。

```bash
./build.sh          # 构建，默认跟随本机架构(arm64)
./run.sh            # 起容器，宿主 ./data 挂到容器 /data
```

进容器后：

```bash
ls /data            # 就是宿主的 tools_images/data
python3 -c "import pandas; print(pandas.__version__)"
mc --version && aws --version
```

## 挂载外部目录

默认挂的是本目录下的 `data/`。换成别的宿主目录：

```bash
HOST_DATA_DIR=/Users/admin/work/code/tools/dataAcross_check ./run.sh
```

或者 compose：

```bash
HOST_DATA_DIR=/some/other/dir docker compose run --rm pytools
```

容器里统一从 `/data` 访问（脚本里可用环境变量 `$DATA_DIR`）。想挂多个目录，在 `run.sh` 里再加一行 `-v 宿主路径:容器路径`。

## 服务器上出 x86 镜像

Dockerfile 里 `FROM --platform=$TARGETPLATFORM`，平台跟着构建参数走：

```bash
TARGET_PLATFORM=linux/amd64 ./build.sh

# 或者
docker build --platform linux/amd64 -t pytools:3.12 .
TARGET_PLATFORM=linux/amd64 docker compose build
```

导出后推到服务器：

```bash
docker save pytools:3.12 | gzip > pytools-3.12-amd64.tar.gz
# 服务器上
gunzip -c pytools-3.12-amd64.tar.gz | docker load
```

## 下载源 / 国内加速

**镜像层**（`FROM python:3.12-slim-bookworm`）靠 Docker 的 registry mirror 加速，Docker Desktop 里配 `https://docker.m.daocloud.io/` 即可，跟 Dockerfile 无关。

**镜像内部的下载**走的是普通 HTTP，不受 registry mirror 影响，所以 Dockerfile 里默认全部换成了国内源：

| 内容 | 默认源 |
| --- | --- |
| apt 包 | `mirrors.aliyun.com`；在阿里云 ECS 上自动切内网源 `mirrors.cloud.aliyuncs.com` |
| pip 包 | `pypi.tuna.tsinghua.edu.cn` |
| JMeter tgz (87MB) | `mirrors.tuna.tsinghua.edu.cn/apache` |
| maven jar | `maven.aliyun.com/repository/public` |
| mc | `dl.minio.org.cn`（官方中国 CDN） |
| awscli | `awscli.amazonaws.com`（无公开国内镜像） |

不用额外设置，直接 `./build.sh` 就是快的。要换回官方源（比如在国外构建）：

```bash
APT_MIRROR=deb.debian.org \
PIP_INDEX_URL=https://pypi.org/simple \
JMETER_MIRROR=https://dlcdn.apache.org/jmeter/binaries \
MAVEN_MIRROR=https://repo1.maven.org/maven2 \
./build.sh
```

`awscli.amazonaws.com` 没有公开的国内镜像。如果公司内网有 Nexus/Artifactory 代理，用 `AWS_MIRROR` 指过去，注意它是**前缀**，脚本会在后面拼 `/awscli-exe-linux-x86_64.zip`。

`mc` 老地址 `dl.min.io/client/mc/release/...` 已经废弃（410 Gone），现在默认走官方的中国 CDN `dl.minio.org.cn`。

**阿里云 ECS 上** apt 会自动切到内网源 `mirrors.cloud.aliyuncs.com`（构建时探测 3 秒，能通就用）。内网源不占公网带宽，ECS 那种 1-5 Mbps 公网带宽的机器差别很大。想强制指定就传 `APT_MIRROR`。

排查构建慢在哪：每个下载步骤都会 echo 出实际用的源 —— `>>> apt 源: ...`、`>>> pip 源: ...`、`>>> mc 源: ...`、`>>> JMeter tgz 来自 ...`。apt 那步还会在换源失败时直接报错并打印源文件内容，不会闷声慢下去。

两个实现细节：

- **JMeter 的 `.sha512` 仍从 `archive.apache.org` 取**。国内 Apache 镜像只镜像主产物，`.sha512` 是 404。所以 87MB 的包走国内镜像、150 字节的校验文件走官方，校验没丢。
- 每个源都带官方回退，国内镜像挂了会自动落到 `dlcdn`/`archive`/`repo1`，不会直接 build 失败。

## 用 JMeter 压测

镜像里是 5.6.3（`--build-arg JMETER_VERSION=` 可换版本），`jmeter` 已在 PATH 上。

```bash
kubectl -n pytools exec -it deploy/pytools -- bash   # 或 ./run.sh

jmeter --version                    # 5.6.3
cd /data
jmeter -n -t plan.jmx -l result.jtl -e -o report    # 非 GUI 跑，报告出到 report/
```

参数说明：`-n` 非 GUI、`-t` 测试计划、`-l` 结果 jtl、`-e -o` 跑完自动生成 HTML 报告（`-o` 指定的目录必须不存在或是空的）。

常用变体：

```bash
# 远程/分布式压测时指定属性
jmeter -n -t plan.jmx -l result.jtl -Jthreads=500 -Jduration=600

# 加大 JVM 堆（默认 1g）。注意覆盖 JVM_ARGS 时要自己带上 headless
JVM_ARGS="-Xmx4g -Djava.awt.headless=true" jmeter -n -t plan.jmx -l result.jtl
```

插件：

```bash
PluginsManagerCMD.sh status                      # 看已装插件
PluginsManagerCMD.sh install jpgc-casutg         # 装插件，装完要重启 jmeter
```

几点注意：

- **只有非 GUI 模式**。容器里没有 X11，`JVM_ARGS` 默认带 `-Djava.awt.headless=true`，别把 GUI 模式指望在这个镜像上。测试计划在本地 GUI 里画好，`.jmx` 放进挂载目录再进来跑。
- 压测结果和报告写在 `/data`（也就是宿主的挂载目录）下，容器删了数据还在。
- 需要更大堆内存的话，k3s 的 Pod `memory` limit 也要同步调大，否则 JVM 申请不到内存会被 OOMKill。
- 并发压测受容器网络和 CPU 限制，跟物理机跑出来的数不一样，只看趋势别当绝对值。

## k3s 部署

`k3s/` 目录下是 hostPath + 常驻 Pod 的方案。

| 文件 | 作用 |
| --- | --- |
| `pytools.yaml` | Namespace + Deployment，hostPath 挂 `./data` 对应的节点目录 |
| `load-image.sh` | 把镜像导入 k3s 的 containerd（在节点上跑） |
| `deploy.sh` | apply + 等就绪 + 打印 exec 命令 |

### 为什么不能直接 `docker load`

k3s 用 containerd 而不是 docker daemon，`docker build`/`docker load` 出来的镜像它看不见。两条路：

- **导入**：`sudo k3s ctr images import pytools-3.12.tar`（`load-image.sh` 干的就是这个）
- **走 registry**：推到私有仓库，`pytools.yaml` 里把 image 改成仓库地址并加 `imagePullSecrets`

### 步骤

```bash
# 1. 本机构建并导出（服务器是 x86 就带上 TARGET_PLATFORM）
TARGET_PLATFORM=linux/amd64 ./build.sh
docker save pytools:3.12 -o pytools-3.12.tar

# 2. 传到节点
scp pytools-3.12.tar <user>@<node>:~/

# 3. 节点上导入
sudo k3s ctr images import --all-platforms ~/pytools-3.12.tar

# 4. 改 pytools.yaml 里的 hostPath 为节点上的真实路径，然后部署
cd k3s && ./deploy.sh

# 5. 进容器
kubectl -n pytools exec -it deploy/pytools -- bash
```

### 几点注意

- `hostPath` 写在 Pod 规格里，改路径后必须 `kubectl -n pytools rollout restart deploy/pytools` 才会生效（`apply` 本身不够，因为路径没变、只是你改了文件）。
- 多节点集群要把 `nodeSelector` 的注释打开并填节点名，否则 Pod 可能被调度到没有数据的节点上，挂出来是空目录。
- 单副本 + `Recreate` 是有意的：两个副本同时挂一个 hostPath 会互相踩。
- 镜像拉取策略是 `IfNotPresent`，导入过就不会去找远端。

## 备注

- 容器内默认 `root`。在 Mac 上 bind mount 不会产生宿主 root 属主文件；如果在 Linux 服务器上跑并需要非 root，告诉我加个 user。
- 改了 `requirements.txt` 后重新 `./build.sh` 即可，Docker 层缓存会跳过前面的系统工具安装。

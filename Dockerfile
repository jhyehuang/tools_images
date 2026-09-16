# syntax=docker/dockerfile:1
# 默认跟随构建机架构：本机(M 芯片 arm64)直接测脚本最快；
# 服务器上出 x86 镜像只需 docker build --platform linux/amd64 ...
FROM  python:3.12-slim-bookworm

# 下载全部默认走国内镜像（apt 阿里云 / pip 清华 / JMeter 清华 / maven 阿里云）。
# 每个源都能单独覆盖回官方地址，出国构建时用：
#   --build-arg APT_MIRROR=deb.debian.org
#   --build-arg PIP_INDEX_URL=https://pypi.org/simple
#   --build-arg JMETER_MIRROR=https://dlcdn.apache.org/jmeter/binaries
#   --build-arg MAVEN_MIRROR=https://repo1.maven.org/maven2
# 注意：显式传空值会覆盖默认值，所以下面这些都在 RUN 里做了兜底，空 = 用默认。
ARG APT_MIRROR=
ARG PIP_INDEX_URL=
ARG JMETER_MIRROR=
ARG MAVEN_MIRROR=
# mc / awscli 没有公开的国内镜像，默认走官方；
# 公司内网有 Nexus/Artifactory 代理的话可以用这两个指过去。
ARG MC_MIRROR=
ARG AWS_MIRROR=
ARG JMETER_VERSION=
ARG JMETER_PLUGINS_MANAGER=

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Asia/Shanghai \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    DATA_DIR=/data

WORKDIR /work

# ---------- 系统工具 ----------
RUN set -eux; \
    APT_MIRROR="${APT_MIRROR:-mirrors.aliyun.com}"; \
    echo ">>> apt 源: $APT_MIRROR"; \
    for f in /etc/apt/sources.list.d/debian.sources /etc/apt/sources.list; do \
        if [ -f "$f" ]; then sed -i "s|deb.debian.org|$APT_MIRROR|g" "$f"; fi; \
    done; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        bash bash-completion ca-certificates curl wget \
        unzip zip tar gzip xz-utils rsync \
        git vim less jq tree \
        procps psmisc lsof iproute2 iputils-ping dnsutils netcat-openbsd telnet \
        openjdk-17-jre-headless \
        tzdata locales; \
    ln -snf /usr/share/zoneinfo/$TZ /etc/localtime; \
    echo "$TZ" > /etc/timezone; \
    rm -rf /var/lib/apt/lists/*

# JAVA_HOME 指向实际 JDK 目录（amd64/arm64 下路径名不同，用软链统一）
ENV JAVA_HOME=/usr/lib/jvm/default-java
RUN set -eux; \
    ln -sfn "$(dirname "$(dirname "$(readlink -f "$(command -v java)")")")" "$JAVA_HOME"; \
    "$JAVA_HOME/bin/java" -version

# ---------- MinIO mc ----------
RUN set -eux; \
    case "$(uname -m)" in \
        x86_64)  MC_ARCH=amd64 ;; \
        aarch64) MC_ARCH=arm64 ;; \
        *) echo "unsupported arch: $(uname -m)" >&2; exit 1 ;; \
    esac; \
    curl -fsSL "${MC_MIRROR:-https://dl.min.io/client/mc/release}/linux-${MC_ARCH}/mc" -o /usr/local/bin/mc; \
    chmod +x /usr/local/bin/mc

# ---------- AWS CLI v2 ----------
RUN set -eux; \
    case "$(uname -m)" in \
        x86_64)  AWS_ARCH=x86_64 ;; \
        aarch64) AWS_ARCH=aarch64 ;; \
        *) echo "unsupported arch: $(uname -m)" >&2; exit 1 ;; \
    esac; \
    curl -fsSL "${AWS_MIRROR:-https://awscli.amazonaws.com}/awscli-exe-linux-${AWS_ARCH}.zip" -o /tmp/awscliv2.zip; \
    unzip -q /tmp/awscliv2.zip -d /tmp; \
    /tmp/aws/install; \
    rm -rf /tmp/awscliv2.zip /tmp/aws

# ---------- Apache JMeter ----------
# JVM_ARGS 默认 headless：容器里没有 X11。
# 要加大堆内存就覆盖它，例如 -e JVM_ARGS="-Xmx4g -Djava.awt.headless=true"
ENV JMETER_HOME=/opt/jmeter \
    PATH=/opt/jmeter/bin:$PATH \
    JVM_ARGS=-Djava.awt.headless=true

# cmdrunner 是 PluginsManagerCMD.sh 的依赖，缺了插件管理器的命令行用不了
RUN set -eux; \
    JMETER_VER="${JMETER_VERSION:-5.6.3}"; \
    PM_VER="${JMETER_PLUGINS_MANAGER:-2.0}"; \
    JMETER_BASE="${JMETER_MIRROR:-https://mirrors.tuna.tsinghua.edu.cn/apache/jmeter/binaries}"; \
    MAVEN_BASE="${MAVEN_MIRROR:-https://maven.aliyun.com/repository/public}"; \
    cd /tmp; \
    for base in "$JMETER_BASE" \
                "https://dlcdn.apache.org/jmeter/binaries" \
                "https://archive.apache.org/dist/jmeter/binaries"; do \
        if curl -fsSL -o jmeter.tgz "$base/apache-jmeter-${JMETER_VER}.tgz"; then \
            echo ">>> JMeter tgz 来自 $base"; break; \
        fi; \
    done; \
    test -s jmeter.tgz || { echo "JMeter 下载失败：所有源都不可用" >&2; exit 1; }; \
    curl -fsSL -o jmeter.tgz.sha512 \
        "https://archive.apache.org/dist/jmeter/binaries/apache-jmeter-${JMETER_VER}.tgz.sha512"; \
    sed -i "s|apache-jmeter-${JMETER_VER}.tgz|jmeter.tgz|" jmeter.tgz.sha512; \
    sha512sum -c jmeter.tgz.sha512; \
    mkdir -p "$JMETER_HOME"; \
    tar -xzf jmeter.tgz --strip-components=1 -C "$JMETER_HOME"; \
    rm -f jmeter.tgz jmeter.tgz.sha512; \
    curl -fsSL -o "$JMETER_HOME/lib/cmdrunner-2.3.jar" \
        "$MAVEN_BASE/kg/apc/cmdrunner/2.3/cmdrunner-2.3.jar" \
      || curl -fsSL -o "$JMETER_HOME/lib/cmdrunner-2.3.jar" \
        "https://repo1.maven.org/maven2/kg/apc/cmdrunner/2.3/cmdrunner-2.3.jar"; \
    curl -fsSL -o "$JMETER_HOME/lib/ext/jmeter-plugins-manager-${PM_VER}.jar" \
        "$MAVEN_BASE/kg/apc/jmeter-plugins-manager/${PM_VER}/jmeter-plugins-manager-${PM_VER}.jar" \
      || curl -fsSL -o "$JMETER_HOME/lib/ext/jmeter-plugins-manager-${PM_VER}.jar" \
        "https://repo1.maven.org/maven2/kg/apc/jmeter-plugins-manager/${PM_VER}/jmeter-plugins-manager-${PM_VER}.jar"; \
    unzip -p "$JMETER_HOME/lib/ext/jmeter-plugins-manager-${PM_VER}.jar" \
        org/jmeterplugins/repository/PluginsManagerCMD.sh > "$JMETER_HOME/bin/PluginsManagerCMD.sh"; \
    chmod +x "$JMETER_HOME/bin/jmeter" "$JMETER_HOME/bin/jmeter-server" "$JMETER_HOME/bin/PluginsManagerCMD.sh"; \
    ln -sf "$JMETER_HOME/bin/jmeter" /usr/local/bin/jmeter

# ---------- Python 依赖 ----------
COPY requirements.txt /tmp/requirements.txt
RUN --mount=type=cache,target=/root/.cache/pip \
    set -eux; \
    PIP_OPTS=""; \
    if [ -n "${PIP_INDEX_URL:-}" ]; then \
        PIP_OPTS="-i $PIP_INDEX_URL"; \
    else \
        PIP_OPTS="-i https://pypi.tuna.tsinghua.edu.cn/simple"; \
    fi; \
    echo ">>> pip 源: $PIP_OPTS"; \
    pip install $PIP_OPTS -r /tmp/requirements.txt

# ---------- 版本自检（构建时失败好过运行时才发现） ----------
RUN set -eux; \
    python3 --version; \
    pip --version; \
    mc --version; \
    aws --version; \
    jq --version; \
    git --version; \
    java -version; \
    jmeter --version

# 外部目录的挂载点（build 时不存在也没关系，运行时由 -v 覆盖）
RUN mkdir -p /data

CMD ["/bin/bash"]

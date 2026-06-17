# 预装 Claude Code + 三个 plugin 的 CI 镜像
# ⚠️ 构建这台机器需要能访问 npm registry 和 github.com(仅构建时一次性需要)
FROM node:24-slim

# 0) 版本号入参:CI 传入具体 Claude Code 版本,本地构建默认 latest
#    镜像 tag 与此版本号统一(见 .github/workflows/build.yml)
ARG CC_VERSION=latest
LABEL org.opencontainers.image.title="cc-docker" \
      org.opencontainers.image.description="预装 Claude Code + plugins 的 CI 镜像" \
      org.opencontainers.image.source="https://github.com/methol/cc-docker" \
      org.opencontainers.image.version="${CC_VERSION}"

# 1) 基础工具:git + 常用开发工具
RUN apt-get update && apt-get install -y --no-install-recommends \
        git git-lfs \
        curl wget ca-certificates bash \
        openssh-client \
        jq \
        ripgrep \
        fd-find \
        tree \
        make \
        python3 python3-pip \
        unzip \
        less \
        procps \
    && ln -s /usr/bin/fdfind /usr/local/bin/fd \
    && rm -rf /var/lib/apt/lists/*

# 2) 安装 Claude Code CLI(钉死到 CI 传入的版本,保证镜像内版本 = 镜像 tag)
RUN npm install -g @anthropic-ai/claude-code@${CC_VERSION}

# 3) 固定 HOME,保证「构建期安装位置」与「运行期读取位置」一致(关键)
ENV HOME=/root

# 4) 关键坑:claude plugin 默认用 SSH clone GitHub,build 环境无 SSH key
#    用 git insteadOf 改写为 HTTPS,免密 clone 公开仓库
RUN git config --global url."https://github.com/".insteadOf "git@github.com:"

# 5) 添加 marketplace(官方 + karpathy 第三方)
RUN claude plugin marketplace add anthropics/claude-plugins-official \
 && claude plugin marketplace add forrestchang/andrej-karpathy-skills

# 6) 安装三个 plugin(user scope,落在 /root/.claude,固化进镜像层)
RUN claude plugin install code-review@claude-plugins-official        --scope user \
 && claude plugin install security-guidance@claude-plugins-official  --scope user \
 && claude plugin install andrej-karpathy-skills@karpathy-skills     --scope user

# 7) 构建期自检:装不上就让 build 失败,别等到 CI 才发现
RUN claude plugin list | grep -Eq "code-review.*enabled|✔" && echo "✅ plugins ready"

WORKDIR /workspace

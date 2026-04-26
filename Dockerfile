# syntax=docker/dockerfile:1.7
ARG UV_VERSION
FROM ghcr.io/astral-sh/uv:${UV_VERSION} AS uvbin

FROM ubuntu:questing AS base

ARG UV_VERSION
ARG NODE_VERSION
ARG SERENA_VERSION
ARG TARGETARCH
ARG OPENCODE_VERSION=1.3.7
ARG BUN_VERSION=1.3.11
ARG AGENT_UID=1000

RUN echo "UV_VERSION=${UV_VERSION}" && \
    echo "NODE_VERSION=${NODE_VERSION}" && \
    echo "BUN_VERSION=${BUN_VERSION}" && \
    echo "OPENCODE_VERSION=${OPENCODE_VERSION}"

LABEL com.docker.sandboxes="templates" \
      com.docker.sandboxes.base="ubuntu:questing" \
      com.docker.sandboxes.flavor="opencode" \
      org.opencontainers.image.title="OpenCode Docker Sandbox (bunx variant)" \
      org.opencontainers.image.description="Docker Sandbox-compatible OpenCode image running OpenCode via bun x" \
      org.opencontainers.image.version="25.10" \
      org.opencontainers.image.ref.name="ubuntu"

ENV DEBIAN_FRONTEND=noninteractive \
    NPM_CONFIG_PREFIX=/usr/local/share/npm-global \
    BASH_ENV=/etc/sandbox-persistent.sh \
    XDG_CONFIG_HOME=/home/agent/.config \
    XDG_DATA_HOME=/home/agent/.local/share \
    XDG_STATE_HOME=/home/agent/.local/state \
    XDG_CACHE_HOME=/home/agent/.cache \
    OPENCODE_CONFIG_DIR=/home/agent/.config/opencode \
    UV_TOOL_BIN_DIR=/home/agent/.local/bin \
    UV_CACHE_DIR=/home/agent/.cache/uv \
    UV_PYTHON_INSTALL_DIR=/home/agent/.local/share/uv/python \
    UV_LINK_MODE=copy \
    BUN_INSTALL_CACHE_DIR=/home/agent/.cache/bun \
    NO_PROXY=localhost,127.0.0.1,::1,172.17.0.0/16 \
    no_proxy=localhost,127.0.0.1,::1,172.17.0.0/16 \
    PATH=/home/agent/.local/bin:/usr/local/share/npm-global/bin:/usr/local/bin:/usr/local/sbin:/usr/sbin:/sbin:/usr/bin:/bin \
    HUSKY=0 \
    CI=1

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

COPY --from=uvbin /uv /uvx /usr/local/bin/

FROM base AS apt-packages

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      bash \
      build-essential \
      ca-certificates \
      curl \
      file \
      git \
      jq \
      less \
      make \
      nano \
      openssh-client \
      procps \
      python3 \
      python3-pip \
      python3-venv \
      ripgrep \
      sudo \
      tini \
      tree \
      vim \
      xz-utils \
      unzip; \
    if ! apt-get install -y --no-install-recommends golang-go; then \
      apt-get install -y --no-install-recommends golang-1.23-go; \
    fi; \
    rm -rf /var/lib/apt/lists/*

FROM apt-packages AS nodejs

RUN install -d -m 0755 /usr/local/share/npm-global; \
    case "${TARGETARCH:-$(dpkg --print-architecture)}" in \
      arm64) node_arch='arm64' ;; \
      amd64) node_arch='x64' ;; \
      *) echo "Unsupported TARGETARCH: ${TARGETARCH:-unknown}" >&2; exit 1 ;; \
    esac; \
    node_version="$(curl -fsSL https://nodejs.org/dist/index.json | jq -r --arg ver "v${NODE_VERSION}" '[.[] | select(.version == $ver)][0].version')"; \
    test -n "$node_version"; \
    curl -fsSLO "https://nodejs.org/dist/${node_version}/node-${node_version}-linux-${node_arch}.tar.xz"; \
    curl -fsSLO "https://nodejs.org/dist/${node_version}/SHASUMS256.txt"; \
    grep " node-${node_version}-linux-${node_arch}.tar.xz$" SHASUMS256.txt | sha256sum -c -; \
    tar -xJf "node-${node_version}-linux-${node_arch}.tar.xz" -C /usr/local --strip-components=1 --no-same-owner; \
    rm -f "node-${node_version}-linux-${node_arch}.tar.xz" SHASUMS256.txt

FROM nodejs AS bun

RUN case "${TARGETARCH:-$(dpkg --print-architecture)}" in \
      arm64) bun_arch='aarch64' ;; \
      amd64) bun_arch='x64' ;; \
      *) echo "Unsupported TARGETARCH: ${TARGETARCH:-unknown}" >&2; exit 1 ;; \
    esac; \
    curl -fsSL "https://github.com/oven-sh/bun/releases/download/bun-v${BUN_VERSION}/bun-linux-${bun_arch}.zip" -o /tmp/bun.zip; \
    cd /tmp; \
    unzip bun.zip; \
    install -m 0755 "/tmp/bun-linux-${bun_arch}/bun" /usr/local/bin/bun; \
    rm -rf /tmp/bun.zip "/tmp/bun-linux-${bun_arch}"

FROM bun AS verify-installations

RUN node --version && \
    npm --version && \
    bun --version && \
    uv --version && \
    uvx --version && \
    python3 --version && \
    pip3 --version && \
    go version

FROM verify-installations AS go-setup

RUN if ! command -v go >/dev/null 2>&1; then \
      go_bin="$(compgen -G '/usr/lib/go-*/bin/go' | head -n1 || true)"; \
      test -n "$go_bin"; \
      ln -sf "$go_bin" /usr/local/bin/go; \
      ln -sf "${go_bin%/go}/gofmt" /usr/local/bin/gofmt; \
    fi

FROM go-setup AS user-setup

RUN set -eux; \
    if id -u agent >/dev/null 2>&1; then \
      :; \
    elif getent passwd "${AGENT_UID}" >/dev/null 2>&1; then \
      useradd --create-home --shell /bin/bash agent; \
    else \
      useradd --create-home --shell /bin/bash --uid "${AGENT_UID}" agent; \
    fi; \
    usermod -aG sudo agent; \
    echo 'agent ALL=(ALL) NOPASSWD:ALL' >/etc/sudoers.d/90-agent; \
    chmod 0440 /etc/sudoers.d/90-agent; \
    install -d -o agent -g agent /home/agent/workspace; \
    install -d -o agent -g agent /home/agent/.config; \
    install -d -o agent -g agent /home/agent/.config/opencode; \
    install -d -o agent -g agent /home/agent/.local; \
    install -d -o agent -g agent /home/agent/.local/bin; \
    install -d -o agent -g agent /home/agent/.local/share; \
    install -d -o agent -g agent /home/agent/.local/share/opencode; \
    install -d -o agent -g agent /home/agent/.local/share/uv; \
    install -d -o agent -g agent /home/agent/.local/share/uv/python; \
    install -d -o agent -g agent /home/agent/.local/state; \
    install -d -o agent -g agent /home/agent/.local/state/opencode; \
    install -d -o agent -g agent /home/agent/.cache; \
    install -d -o agent -g agent /home/agent/.cache/opencode; \
    install -d -o agent -g agent /home/agent/.cache/uv; \
    install -d -o agent -g agent /home/agent/.cache/bun; \
    chown -R agent:agent /home/agent

FROM user-setup AS config-copy

COPY sandbox-persistent.sh /etc/sandbox-persistent.sh
COPY bashrc.sandbox /home/agent/.bashrc.sandbox
COPY entrypoint.sh /usr/local/bin/opencode-entrypoint
COPY docker/scripts/sandbox-localhost-bridge.js /usr/local/lib/opencode/sandbox-localhost-bridge.js
COPY docker/scripts/qwen-cot-bridge.js /usr/local/lib/opencode/qwen-cot-bridge.js
COPY docker/configs/opencode.json /tmp/opencode.json
COPY docker/configs/opencode_serena.json /tmp/opencode_serena.json

RUN if [ -n "${SERENA_VERSION:-}" ]; then \
      mv /tmp/opencode_serena.json /home/agent/.config/opencode/opencode.json && \
      uv tool install "git+https://github.com/oraios/serena@v${SERENA_VERSION}"; \
    else \
      mv /tmp/opencode.json /home/agent/.config/opencode/opencode.json; \
    fi && \
    rm -f /tmp/opencode.json /tmp/opencode_serena.json

RUN cat >/usr/local/bin/opencode <<EOF
#!/usr/bin/env bash
set -euo pipefail

BRIDGE_SCRIPT="/usr/local/lib/opencode/sandbox-localhost-bridge.js"
QWEN_BRIDGE_SCRIPT="/usr/local/lib/opencode/qwen-cot-bridge.js"

ensure_sandbox_localhost_bridge() {
  local state_dir pid_file log_file pid

  state_dir="\${XDG_STATE_HOME:-\$HOME/.local/state}/opencode"
  pid_file="\$state_dir/sandbox-localhost-bridge.pid"
  log_file="\$state_dir/sandbox-localhost-bridge.log"

  mkdir -p "\$state_dir"

  if [ ! -f "\$BRIDGE_SCRIPT" ]; then
    echo "warning: bridge script not found at \$BRIDGE_SCRIPT; continuing without localhost bridge" >&2
    return 0
  fi

  if ! command -v node >/dev/null 2>&1; then
    echo "warning: node is not installed; continuing without localhost bridge" >&2
    return 0
  fi

  if [ -f "\$pid_file" ]; then
    pid="\$(cat "\$pid_file" 2>/dev/null || true)"
    if [ -n "\$pid" ] && kill -0 "\$pid" 2>/dev/null; then
      return 0
    fi
    rm -f "\$pid_file"
  fi

  nohup node "\$BRIDGE_SCRIPT" >>"\$log_file" 2>&1 &
  pid=\$!
  echo "\$pid" > "\$pid_file"

  if ! kill -0 "\$pid" 2>/dev/null; then
    echo "warning: failed to start sandbox localhost bridge; continuing" >&2
    rm -f "\$pid_file"
  fi
}

ensure_qwen_cot_bridge() {
  local state_dir pid_file log_file pid

  state_dir="\${XDG_STATE_HOME:-\$HOME/.local/state}/opencode"
  pid_file="\$state_dir/qwen-cot-bridge.pid"
  log_file="\$state_dir/qwen-cot-bridge.log"

  mkdir -p "\$state_dir"

  if [ ! -f "\$QWEN_BRIDGE_SCRIPT" ]; then
    echo "warning: qwen bridge script not found at \$QWEN_BRIDGE_SCRIPT; continuing without it" >&2
    return 0
  fi

  if ! command -v node >/dev/null 2>&1; then
    return 0
  fi

  if [ -f "\$pid_file" ]; then
    pid="\$(cat "\$pid_file" 2>/dev/null || true)"
    if [ -n "\$pid" ] && kill -0 "\$pid" 2>/dev/null; then
      return 0
    fi
    rm -f "\$pid_file"
  fi

  nohup node "\$QWEN_BRIDGE_SCRIPT" >>"\$log_file" 2>&1 &
  pid=\$!
  echo "\$pid" > "\$pid_file"
}

should_init_serena() {
  local env_file
  env_file="\$PWD/.env"

  [ -f "\$env_file" ] || return 1

  grep -Eq '^[[:space:]]*(export[[:space:]]+)?INIT_SERENA_IN_REPO=1[[:space:]]*$' "\$env_file"
}

ensure_serena_project() {
  if ! should_init_serena; then
    return 0
  fi

  if ! command -v serena >/dev/null 2>&1; then
    echo "warning: Serena is not installed in the image; continuing without Serena bootstrap" >&2
    return 0
  fi

  serena init >/dev/null 2>&1 || true

  if [ ! -f ".serena/project.yml" ]; then
    echo "Initializing Serena project in \$PWD..." >&2
    serena project create --index
  fi
}

orig_pwd="\$PWD"

if [ "\$#" -eq 0 ]; then
  set -- "\$orig_pwd"
else
  args=()
  for arg in "\$@"; do
    if [ "\$arg" = "." ]; then
      args+=("\$orig_pwd")
    else
      args+=("\$arg")
    fi
  done
  set -- "\${args[@]}"
fi

ensure_sandbox_localhost_bridge
ensure_qwen_cot_bridge
[ -n "${SERENA_VERSION}" ] && ensure_serena_project

exec bun x --package "opencode-ai@${OPENCODE_VERSION}" opencode "\$@"
EOF

RUN set -eux; \
    chmod 0755 /etc/sandbox-persistent.sh /usr/local/bin/opencode-entrypoint /usr/local/bin/opencode; \
    chmod 0644 /usr/local/lib/opencode/sandbox-localhost-bridge.js /usr/local/lib/opencode/qwen-cot-bridge.js; \
    chown -R agent:agent /home/agent; \
    echo 'source ~/.bashrc.sandbox' >> /home/agent/.bashrc

FROM config-copy AS final

USER agent
WORKDIR /home/agent
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/opencode-entrypoint"]
CMD ["opencode"]

# syntax=docker/dockerfile:1.9
# javadev Containerfile — OCI, builds with Docker AND Podman.
# SPDX-License-Identifier: Apache-2.0 OR MIT
#
# Multi-stage, hardened, ultra-small Java dev image on the langdev v2
# foundation. The `toolchain` stage fetches + checksum-verifies the build tools
# (Maven, Gradle) and the LSP/formatter (Eclipse JDT LS, google-java-format)
# into a single relocatable prefix; the `final` stage installs the musl OpenJDK
# from Alpine and copies that prefix in.
#
# The developer environment (shell, editor, tmux) is the USER'S OWN
# chezmoi-managed dotfiles, cloned + applied at build time (latest by default;
# pin with DOTFILES_REF). Everything between the "COMMON BASE" banner and here
# is identical across the suite (kept in sync via `make sync-common`). javadev
# adds only the Java toolchain + a single nvim/plugins.local/lang.lua LSP spec.
#
# Pin the base by DIGEST. Update via `make bump-base` (looks up the
# current digest for the tag and rewrites the two lines below).
ARG ALPINE_VERSION=3.22
# renovate: datasource=docker depName=alpine
ARG ALPINE_DIGEST=sha256:14358309a308569c32bdc37e2e0e9694be33a9d99e68afb0f5ff33cc1f695dce

ARG USERNAME=dev
ARG USER_UID=1000
ARG USER_GID=1000

# Dotfiles source — "always the latest" by default; pin a tag/commit for
# reproducible builds.
ARG DOTFILES_REPO=https://github.com/sebastienrousseau/dotfiles.git
ARG DOTFILES_REF=main

###############################################################################
# Stage: toolchain  (LANGUAGE-SPECIFIC — Java build tools + LSP + formatter)
#   Downloads pinned, checksum-verified releases of Maven, Gradle, the Eclipse
#   JDT Language Server and google-java-format into one relocatable prefix
#   (/opt/langdev/toolchain) that the final stage copies in. No `curl | sh`,
#   no build tools leak into the runtime image. The JDK itself is installed
#   from Alpine's musl OpenJDK in the final stage (it is the actual runtime).
###############################################################################
FROM alpine:${ALPINE_VERSION}@${ALPINE_DIGEST} AS toolchain

# Pinned, checksum-verified toolchain inputs. Bump together (see README).
ARG MAVEN_VERSION=3.9.16
ARG MAVEN_SHA512=831a8591fe20c8243b1dbe7d71e3244f31d1665b0804b2e825e38cbbe5ce0cafb8338851f90780735568773e0a6cd07bbec107cda0b896b008b861075358b6f6
ARG GRADLE_VERSION=9.7.1
ARG GRADLE_SHA256=acd53f1edaf02f1a8ff99879f8a34b302661a057d9b063ae9e35b552f804d20a
# Eclipse JDT Language Server (stable milestone; immutable dated tarball).
ARG JDTLS_VERSION=1.60.0
ARG JDTLS_BUILD=202606262232
ARG JDTLS_SHA256=e94c303d8198f977930803582738771fd18c52c5492878410bf222b1aa81ef1d
ARG GJF_VERSION=1.36.1
ARG GJF_SHA256=25b400f003089d23cc5320cdaf1a16cabee19b8aa3434d0ff021b3d9f42154b4

ENV TOOLCHAIN=/opt/langdev/toolchain

# Build-only fetch/extract tools. These stay in the toolchain stage and never
# reach the runtime image.
# hadolint ignore=DL3018
RUN apk add --no-cache \
      bash \
      ca-certificates \
      curl \
      tar \
      gzip \
      unzip \
 && update-ca-certificates

# Maven — verify the upstream .sha512, then relocate to a version-independent
# prefix ($TOOLCHAIN/maven) so PATH stays stable across bumps.
RUN set -eux; \
    url="https://downloads.apache.org/maven/maven-3/${MAVEN_VERSION}/binaries/apache-maven-${MAVEN_VERSION}-bin.tar.gz"; \
    curl -fsSL "$url" -o /tmp/maven.tar.gz; \
    echo "${MAVEN_SHA512}  /tmp/maven.tar.gz" | sha512sum -c -; \
    mkdir -p "${TOOLCHAIN}"; \
    tar -xzf /tmp/maven.tar.gz -C "${TOOLCHAIN}"; \
    mv "${TOOLCHAIN}/apache-maven-${MAVEN_VERSION}" "${TOOLCHAIN}/maven"; \
    rm -f /tmp/maven.tar.gz

# Gradle — verify the upstream .sha256, then relocate to $TOOLCHAIN/gradle.
RUN set -eux; \
    url="https://services.gradle.org/distributions/gradle-${GRADLE_VERSION}-bin.zip"; \
    curl -fsSL "$url" -o /tmp/gradle.zip; \
    echo "${GRADLE_SHA256}  /tmp/gradle.zip" | sha256sum -c -; \
    unzip -q /tmp/gradle.zip -d "${TOOLCHAIN}"; \
    mv "${TOOLCHAIN}/gradle-${GRADLE_VERSION}" "${TOOLCHAIN}/gradle"; \
    rm -f /tmp/gradle.zip

# Eclipse JDT Language Server (jdtls) — pinned stable milestone tarball, sha256
# verified. Extracted into $TOOLCHAIN/jdtls (bin/, plugins/, config_linux/...).
RUN set -eux; \
    url="https://download.eclipse.org/jdtls/milestones/${JDTLS_VERSION}/jdt-language-server-${JDTLS_VERSION}-${JDTLS_BUILD}.tar.gz"; \
    curl -fsSL "$url" -o /tmp/jdtls.tar.gz; \
    echo "${JDTLS_SHA256}  /tmp/jdtls.tar.gz" | sha256sum -c -; \
    mkdir -p "${TOOLCHAIN}/jdtls"; \
    tar -xzf /tmp/jdtls.tar.gz -C "${TOOLCHAIN}/jdtls"; \
    rm -f /tmp/jdtls.tar.gz

# google-java-format — pinned "all-deps" fat jar, sha256 verified.
RUN set -eux; \
    url="https://github.com/google/google-java-format/releases/download/v${GJF_VERSION}/google-java-format-${GJF_VERSION}-all-deps.jar"; \
    mkdir -p "${TOOLCHAIN}/google-java-format"; \
    curl -fsSL "$url" -o "${TOOLCHAIN}/google-java-format/google-java-format.jar"; \
    echo "${GJF_SHA256}  ${TOOLCHAIN}/google-java-format/google-java-format.jar" | sha256sum -c -

# Launchers on PATH. Written as POSIX sh so the runtime needs no Python (the
# jdtls tarball bundles a Python launcher; we deliberately avoid pulling
# Python into the image). Both resolve the JDK via $JAVA_HOME.
COPY <<'EOF' ${TOOLCHAIN}/bin/jdtls
#!/bin/sh
# jdtls — start the Eclipse JDT Language Server against the build-time JDK.
# Read-only-rootfs friendly: the bundled config_linux is used as a read-only
# shared configuration and a writable per-user configuration + data workspace
# live under $XDG_CACHE_HOME (a tmpfs mount in the hardened runtime).
set -eu
JDTLS_HOME=/opt/langdev/toolchain/jdtls
JAVA_HOME=${JAVA_HOME:-/usr/lib/jvm/java-21-openjdk}
launcher=$(ls "$JDTLS_HOME"/plugins/org.eclipse.equinox.launcher_*.jar 2>/dev/null | head -n1)
if [ -z "$launcher" ]; then
  echo "jdtls: equinox launcher jar not found under $JDTLS_HOME/plugins" >&2
  exit 1
fi
shared_config="$JDTLS_HOME/config_linux"
data="${JDTLS_DATA_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/jdtls/workspace}"
user_config="${data}/config"
mkdir -p "$user_config"
exec "$JAVA_HOME/bin/java" \
  -Declipse.application=org.eclipse.jdt.ls.core.id1 \
  -Dosgi.bundles.defaultStartLevel=4 \
  -Declipse.product=org.eclipse.jdt.ls.core.product \
  -Dosgi.checkConfiguration=true \
  -Dosgi.sharedConfiguration.area="$shared_config" \
  -Dosgi.sharedConfiguration.area.readOnly=true \
  -Dosgi.configuration.cascaded=true \
  -Dlog.level=ALL \
  -Xms256m -Xmx2g \
  --add-modules=ALL-SYSTEM \
  --add-opens java.base/java.util=ALL-UNNAMED \
  --add-opens java.base/java.lang=ALL-UNNAMED \
  -jar "$launcher" \
  -configuration "$user_config" \
  -data "$data" \
  "$@"
EOF

COPY <<'EOF' ${TOOLCHAIN}/bin/google-java-format
#!/bin/sh
# google-java-format — format Java sources with the pinned fat jar. The
# --add-exports flags are required to run the formatter on a modular JDK (16+).
set -eu
JAVA_HOME=${JAVA_HOME:-/usr/lib/jvm/java-21-openjdk}
exec "$JAVA_HOME/bin/java" \
  --add-exports jdk.compiler/com.sun.tools.javac.api=ALL-UNNAMED \
  --add-exports jdk.compiler/com.sun.tools.javac.file=ALL-UNNAMED \
  --add-exports jdk.compiler/com.sun.tools.javac.parser=ALL-UNNAMED \
  --add-exports jdk.compiler/com.sun.tools.javac.tree=ALL-UNNAMED \
  --add-exports jdk.compiler/com.sun.tools.javac.util=ALL-UNNAMED \
  -jar /opt/langdev/toolchain/google-java-format/google-java-format.jar "$@"
EOF

RUN chmod 0755 "${TOOLCHAIN}/bin/jdtls" "${TOOLCHAIN}/bin/google-java-format"

###############################################################################
# Stage: env-build  (COMMON — apply the user's dotfiles + bake nvim plugins)
###############################################################################
FROM alpine:${ALPINE_VERSION}@${ALPINE_DIGEST} AS env-build
ARG USERNAME USER_UID USER_GID DOTFILES_REPO DOTFILES_REF
# Tools needed to clone+apply dotfiles and compile/install nvim plugins.
# hadolint ignore=DL3018
RUN apk add --no-cache \
      bash ca-certificates chezmoi curl git \
      neovim ripgrep fd fzf bat \
      build-base cmake
RUN addgroup -g "${USER_GID}" "${USERNAME}" \
 && adduser -D -u "${USER_UID}" -G "${USERNAME}" -s /bin/bash "${USERNAME}"
COPY --chown=${USER_UID}:${USER_GID} common/bootstrap-dotfiles.sh /usr/local/bin/langdev-bootstrap-dotfiles
RUN chmod 0755 /usr/local/bin/langdev-bootstrap-dotfiles
USER ${USERNAME}
ENV HOME=/home/${USERNAME}
# 1) Clone + chezmoi-apply the user's dotfiles (brings bashrc, tmux, nvim…).
RUN DOTFILES_REPO="${DOTFILES_REPO}" DOTFILES_REF="${DOTFILES_REF}" \
      langdev-bootstrap-dotfiles
# 2) Drop the language LSP spec into the dotfiles' nvim (auto-imported via
#    the config's `plugins.local`), then bake the full plugin set headless
#    so the runtime needs no network on first launch.
COPY --chown=${USER_UID}:${USER_GID} nvim/plugins.local/ /home/${USERNAME}/.config/nvim/lua/plugins.local/
RUN nvim --headless "+Lazy! restore" +qa 2>&1 | tail -n 5 || true \
 && nvim --headless "+Lazy! sync"    +qa 2>&1 | tail -n 5 || true \
 && nvim --headless "+TSUpdateSync"  +qa 2>&1 | tail -n 5 || true

###############################################################################
#                              COMMON BASE
###############################################################################
FROM alpine:${ALPINE_VERSION}@${ALPINE_DIGEST} AS base
ARG USERNAME USER_UID USER_GID

LABEL org.opencontainers.image.title="javadev" \
      org.opencontainers.image.licenses="Apache-2.0 OR MIT" \
      org.opencontainers.image.vendor="Sebastien Rousseau"

# Runtime deps: editor, multiplexer (tmux — available by default), and the
# CLI tools the dotfiles expect. `tini` is PID 1 (compose sets init:true).
# hadolint ignore=DL3018
RUN apk add --no-cache \
      bash \
      bat \
      ca-certificates \
      chezmoi \
      curl \
      fd \
      fzf \
      git \
      less \
      mosh-server \
      neovim \
      ripgrep \
      tini \
      tmux \
      ttyd \
      tzdata \
      zoxide \
 && update-ca-certificates

RUN addgroup -g "${USER_GID}" "${USERNAME}" \
 && adduser -D -u "${USER_UID}" -G "${USERNAME}" -s /bin/bash "${USERNAME}"

# Bring in the fully-populated home from env-build: the applied dotfiles
# (~/.bashrc, ~/.config/tmux, ~/.config/nvim, ~/.config/shell/*, …) plus the
# baked nvim plugin set. One COPY captures everything chezmoi wrote.
COPY --from=env-build --chown=${USER_UID}:${USER_GID} /home/${USERNAME} /home/${USERNAME}

# Entrypoint & IDE tooling (tmux-loading, strict-mode, AI & MCP).
COPY common/entrypoint.sh /usr/local/bin/langdev-entrypoint
COPY common/tmux-ide.sh /usr/local/bin/tmux-ide
COPY common/muxtree.sh /usr/local/bin/muxtree
COPY common/doctor.sh /usr/local/bin/langdev-doctor
COPY common/mcp-server.sh /usr/local/bin/mcp-server
COPY common/ai-pack.sh /usr/local/bin/ai-pack
COPY common/explorer.sh /usr/local/bin/langdev-explorer
COPY common/mcp.json /etc/langdev-mcp.json
COPY common/tmux.conf /etc/tmux.conf
RUN chmod 0755 /usr/local/bin/langdev-entrypoint /usr/local/bin/tmux-ide /usr/local/bin/muxtree \
               /usr/local/bin/langdev-doctor /usr/local/bin/mcp-server /usr/local/bin/ai-pack \
               /usr/local/bin/langdev-explorer \
 && chmod 0644 /etc/tmux.conf /etc/langdev-mcp.json \
 && mkdir -p /usr/local/lib/langdev

# --- Hardening ---------------------------------------------------------------
# Sticky bit preserved (1777, NOT 777). Strip setuid/setgid bits everywhere.
RUN chmod 1777 /tmp \
 && find / -xdev -type f \( -perm -4000 -o -perm -2000 \) -exec chmod -s {} + 2>/dev/null || true

USER ${USERNAME}
WORKDIR /work
ENV HOME=/home/${USERNAME} \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    EDITOR=nvim \
    XDG_CONFIG_HOME=/home/${USERNAME}/.config \
    XDG_DATA_HOME=/home/${USERNAME}/.local/share \
    XDG_STATE_HOME=/home/${USERNAME}/.local/state \
    XDG_CACHE_HOME=/home/${USERNAME}/.cache

# Cheap, honest liveness probe (no full-FS scans).
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD nvim --version >/dev/null 2>&1 || exit 1

ENTRYPOINT ["/usr/local/bin/langdev-entrypoint"]

###############################################################################
# Stage: final  (Java runtime — musl OpenJDK + relocatable build tools/LSP)
#   Installs Alpine's musl OpenJDK 21 (the JDK is the real runtime: java,
#   javac) and copies in the relocatable $TOOLCHAIN prefix built + verified in
#   the toolchain stage. No curl/unzip/build-base here.
###############################################################################
FROM base AS final

# Alpine's musl-native OpenJDK LTS. Pinned to the exact package build present
# in the digest-locked v3.22 community repo (bump alongside the base digest;
# see README). openjdk21 pulls in java-common, which provides the
# /usr/lib/jvm/default-jvm symlink.
# hadolint ignore=DL3018
USER root
RUN apk add --no-cache "openjdk21=21.0.11_p10-r0" \
 && java -version

# Relocatable Java build tools + LSP + formatter, checksum-verified upstream.
COPY --from=toolchain --chown=1000:1000 /opt/langdev/toolchain /opt/langdev/toolchain

# Language env for LOGIN shells: JAVA_HOME + PATH (jdk/maven/gradle/toolchain
# bin) + aliases for the installed tools only. Installed root-owned (0644) to
# /etc/profile.d (sourced via /etc/profile) — deliberately kept OUT of the
# user's chezmoi dotfiles so those stay pristine and langdev-agnostic.
COPY dotfiles.d/java.sh /etc/profile.d/java.sh
RUN chmod 0644 /etc/profile.d/java.sh

USER dev

# java, javac, mvn, gradle, jdtls and google-java-format are all on PATH. These
# ENV values duplicate the /etc/profile.d fragment so non-login one-shot
# commands (e.g. `make run CMD="mvn -version"`, which do not source /etc/profile)
# still resolve the toolchain. The profile.d fragment is PATH-idempotent, so the
# two never conflict or duplicate entries.
ENV JAVA_HOME=/usr/lib/jvm/java-21-openjdk \
    MAVEN_HOME=/opt/langdev/toolchain/maven \
    GRADLE_HOME=/opt/langdev/toolchain/gradle \
    PATH=/usr/lib/jvm/java-21-openjdk/bin:/opt/langdev/toolchain/bin:/opt/langdev/toolchain/maven/bin:/opt/langdev/toolchain/gradle/bin:/home/dev/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

<!-- SPDX-License-Identifier: Apache-2.0 OR MIT -->

# Changelog

All notable changes to this project are documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
This project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.0.4] - 2026-08-29

### Added

- **TUI Power Suite & Interactive Explorer.**
  - Added `common/explorer.sh` providing an interactive TUI sidebar for Left Panel navigation with Git branch context, dirty file indicators, visual tree view, and Neovim editor dispatch.
  - Enhanced `common/tmux-ide.sh` to auto-detect and launch Yazi or the interactive project explorer.
- **Bats Unit Tests.**
  - Added `test/explorer.bats`.

## [0.0.3] - 2026-08-29

### Added

- **Model Context Protocol (MCP) Server Suite.**
  - Added `common/mcp-server.sh` implementing JSON-RPC 2.0 stdio transport exposing workspace tools (`list_files`, `read_file`, `git_status`, `git_diff`, `run_tests`, `run_command`) to AI coding agents.
  - Added `common/mcp.json` configuration template for Claude Code, Cursor, and Aider.
- **AI Context Packing (`ai-pack`).**
  - Added `common/ai-pack.sh` for fast, token-efficient XML and Markdown codebase bundling respecting `.gitignore`.
- **Local LLM Routing.**
  - Added automatic resolution for local Ollama instances (`http://host.containers.internal:11434`).
- **Bats Unit Tests.**
  - Added `test/mcp.bats` and `test/ai-pack.bats`.

## [0.0.2] - 2026-08-29

### Added

- **Remote & Mobile Web Access.**
  - `make web` and `make web-auth` targets using `ttyd` for browser-based access on iPads and mobile devices over WebSocket/SSL.
  - `make mosh` for UDP-based roaming mobile shell sessions that survive connection drops.
- **Diagnostic CLI (`make doctor`).**
  - Added `common/doctor.sh` to probe host engines, architecture, cgroups, kernel security, and clipboard readiness.
- **Universal Clipboard (OSC 52).**
  - Added `set -s set-clipboard on` in `common/tmux.conf` for seamless copy-paste to host/mobile clipboards.
- **TUI Popups.**
  - Added floating TMUX popups for Lazygit (`Prefix + g`) and Lazydocker (`Prefix + d`).
- **VS Code IDE Grid & Parallel Task Worktrees.**
  - Added `common/tmux-ide.sh` (`Prefix + i`) and `common/muxtree.sh` (`Prefix + m`).

## [0.0.1] - 2026-08-29

The initial `javadev` image: a portable, disposable Java development
container built on the shared, hardened [`langdev`](https://github.com/sebastienrousseau/langdev)
core, that builds with **both** Docker and Podman and boots the
developer's own chezmoi-managed dotfiles.

### Added

- **Java toolchain, pinned and checksum-verified.** Alpine's
  musl-native **OpenJDK 21 (LTS)** installed from the digest-locked
  v3.22 repo, plus **Apache Maven 3.9.16** (SHA-512-verified),
  **Gradle 9.7.1** (SHA-256-verified), the **Eclipse JDT Language
  Server 1.60.0** (SHA-256-verified), and **google-java-format 1.36.1**
  (SHA-256-verified). Build tools are fetched in a throwaway
  `toolchain` stage and copied in as a single relocatable prefix, so no
  fetch tooling reaches the runtime image.
- **Java editor wiring.** One `nvim/plugins.local/lang.lua` spec wires
  the Java LSP through `nvim-lspconfig` against the build-time `jdtls`
  launcher, adds the `java` Treesitter grammar, and leaves Mason
  disabled. Plugins are baked headless at build time — no network on
  first launch.
- **Read-only-rootfs-friendly jdtls.** A POSIX-sh launcher runs the JDT
  server against the pre-installed JDK, using the bundled `config_linux`
  as a read-only shared configuration and writing its workspace under
  `$XDG_CACHE_HOME/jdtls` (a `tmpfs`).
- **Java login-shell environment.** `dotfiles.d/java.sh` installed to
  `/etc/profile.d/java.sh` exports `JAVA_HOME` / `MAVEN_HOME` /
  `GRADLE_HOME`, prepends the toolchain `bin` dirs to `PATH`
  idempotently, and defines tool aliases (`j`, `jc`, `mvnci`, `gw`,
  `gjf`, …). The same values are baked as `ENV` for non-login one-shot
  commands.
- **Shared `langdev` core.** Vendored `common/entrypoint.sh` and
  `common/bootstrap-dotfiles.sh`, the hardened `compose.yaml`, and the
  docker/podman-autodetecting `Makefile`, kept in sync via
  `make sync-common`.
- **Security posture, on by default.** Non-root `dev` (UID/GID 1000);
  `cap_drop: [ALL]`; `no-new-privileges`; read-only root filesystem with
  `tmpfs` for writable state; `pids_limit: 512`; **`mem_limit: 4g`**
  (raised from the suite default 2g for JVM/Gradle/jdtls headroom, swap
  disabled); base image pinned by digest; checksum-verified downloads;
  no committed or baked-in secrets.
- **CI gates.** `hadolint`, `shellcheck`, a Docker build, and a Trivy
  image scan (fail on HIGH/CRITICAL) on every push and pull request; a
  CycloneDX SBOM uploaded as an artifact.

### Documentation

- README rewritten to the `langdev` suite house style (centered header,
  badge row, Contents, Quick start, Why this approach?, What's inside,
  Security model, Portability, When not to use javadev, Development,
  Documentation, License).
- Community docs vendored from the suite: [`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md),
  [`CONTRIBUTING.md`](CONTRIBUTING.md), [`SECURITY.md`](SECURITY.md),
  [`SUPPORT.md`](SUPPORT.md), [`GOVERNANCE.md`](GOVERNANCE.md).
- `.github/` scaffolding: `CODEOWNERS`, `FUNDING.yml`, `dependabot.yml`,
  a pull-request template, and issue forms (bug report, feature
  request, plus a config routing questions and security reports).

### Licensing

- Relicensed from single MIT to **dual `Apache-2.0 OR MIT`**. Added
  `LICENSE-APACHE` and `LICENSE-MIT`, removed the single `LICENSE` file,
  and applied `SPDX-License-Identifier: Apache-2.0 OR MIT` headers
  across the non-vendored sources.

[Unreleased]: https://github.com/sebastienrousseau/javadev/commits/main

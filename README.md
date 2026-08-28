<!-- SPDX-License-Identifier: Apache-2.0 OR MIT -->

<p align="center">
  <img src="https://cloudcdn.pro/javadev/v1/logos/javadev.svg" alt="javadev logo" width="128" />
</p>

<h1 align="center">javadev</h1>

<p align="center">
  A portable, disposable Java development container — musl-native
  OpenJDK 21 with pinned, checksum-verified Maven, Gradle, and the
  Eclipse JDT language server, that builds with <b>both</b> Docker and
  Podman and boots the developer's own dotfiles.
</p>

<p align="center">
  <a href="https://github.com/sebastienrousseau/javadev/actions"><img src="https://img.shields.io/github/actions/workflow/status/sebastienrousseau/javadev/ci.yml?style=for-the-badge&logo=github" alt="Build" /></a>
  <a href="#license"><img src="https://img.shields.io/badge/license-Apache--2.0%20OR%20MIT-blue?style=for-the-badge" alt="License: Apache-2.0 OR MIT" /></a>
  <a href="https://scorecard.dev/viewer/?uri=github.com/sebastienrousseau/javadev"><img src="https://img.shields.io/ossf-scorecard/github.com/sebastienrousseau/javadev?style=for-the-badge&label=OpenSSF%20Scorecard&logo=openssf" alt="OpenSSF Scorecard" /></a>
  <a href="#portability"><img src="https://img.shields.io/badge/engines-docker%20%7C%20podman-1d63ed?style=for-the-badge&logo=docker" alt="Engines: Docker or Podman" /></a>
  <a href="#portability"><img src="https://img.shields.io/badge/arch-amd64%20%C2%B7%20arm64-555?style=for-the-badge" alt="Architectures: amd64, arm64" /></a>
</p>

---

## Contents

**Getting started**

- [Quick start](#quick-start) — clone, `make up`, done
- [Why this approach?](#why-this-approach) — the choices that shape the image

**What you get**

- [What's inside](#whats-inside) — the pinned, checksum-verified toolchain
- [The developer environment IS your dotfiles](#the-developer-environment-is-your-dotfiles) — no synthetic config

**Operational**

- [Security model](#security-model) — the container threat model and controls
- [Portability](#portability) — engines, architectures, host assumptions
- [When not to use javadev](#when-not-to-use-javadev) — limitations, stated plainly
- [Development](#development) — `make` targets, lint, scan, SBOM, CI
- [Documentation](#documentation) — community docs and the house style
- [License](#license)

---

## Quick start

`javadev` is standalone. Clone it, and one command gets you an
interactive, hardened shell in a fresh Java container:

```sh
git clone https://github.com/sebastienrousseau/javadev.git
cd javadev
make up                        # build (if needed) + drop into a dev shell
```

`make up` builds for the host architecture and runs the container
non-root, read-only, with all capabilities dropped (see
[Security model](#security-model)). Your project directory is the only
bind mount, at `/work`. Run a one-shot build and exit, or tear the
image down:

```sh
make run CMD="mvn -version"    # one-shot command in a fresh container
make trash                     # remove the image and dangling build cache
```

No registry pull and no network on first launch — the image, including
the Neovim plugin set, is built entirely from the repo you cloned.

`javadev` is a member of the [`langdev`](https://github.com/sebastienrousseau/langdev)
suite: it adds a thin Java layer on top of the shared, hardened
`langdev` core (entrypoint, dotfiles bootstrap, `Containerfile` /
`compose` / `Makefile`), vendored under `common/` and kept in sync with
`make sync-common`.

---

## Why this approach?

Most "Java dev container" setups make one of two trades: a heavyweight,
root-running image with a full JDK distribution and a bundled IDE, or a
bare base that leaves you to install Maven, Gradle, and a language
server by hand every time. javadev refuses both. Four choices, in
priority order, shape the image:

1. **Secure by default, not by opt-in.** The container runs as a
   non-root `dev` user (UID/GID 1000) with **all Linux capabilities
   dropped**, `no-new-privileges`, and a **read-only root filesystem**;
   writable state is confined to explicit `tmpfs` mounts. This is the
   default `make up` posture, not a hardened variant you have to
   remember to select. The threat model is [documented](SECURITY.md),
   not implied.

2. **Ultra-small but complete.** A multi-stage build on an Alpine base
   ships Alpine's **musl-native OpenJDK 21 (LTS)** plus exactly the
   tools a Java workflow needs — Maven, Gradle, an LSP, a formatter,
   an editor — and nothing else. The build tooling (`curl`, `unzip`,
   `tar`) lives only in a throwaway `toolchain` stage; the runtime
   image never sees it. "Complete" is measured against a real workflow:
   you can edit, build, test, and format without reaching outside the
   container.

3. **Portable and disposable.** One OCI `Containerfile` builds with
   Docker, Podman, Buildah, and nerdctl. The `Makefile` auto-detects
   the engine and adjusts flags (SELinux `:Z` mounts) accordingly. The
   image is multi-arch (`linux/amd64`, `linux/arm64`) — Alpine ships
   `openjdk21` for both, and Maven, Gradle, and jdtls are pure-JVM. The
   only bind mount is your project at `/work`, and `make trash` leaves
   nothing behind.

4. **Reliable and reproducible.** Everything is pinned: the base image
   **by digest**, the OpenJDK apk build by version, and every
   downloaded build tool **checksum-verified** — Maven by SHA-512,
   Gradle, jdtls, and google-java-format by SHA-256. There is no
   `curl | sh` anywhere in the build. Pin `DOTFILES_REF` to a tag or
   commit and a build is byte-reproducible.

---

## What's inside

Every runtime input is pinned, and every downloaded input is
checksum-verified against its upstream publisher before it is used.

| Component | Version | How it's pinned |
|---|---|---|
| Alpine base | `3.22` | by digest (`sha256:14358309…695dce`) |
| OpenJDK (musl, LTS) | `21.0.11_p10-r0` | `apk add openjdk21=<ver>` from the digest-locked v3.22 repo |
| Apache Maven | `3.9.16` | `MAVEN_VERSION`; tarball **SHA-512**-verified against `downloads.apache.org` |
| Gradle | `9.7.1` | `GRADLE_VERSION`; `-bin.zip` **SHA-256**-verified against `services.gradle.org` |
| Eclipse JDT LS (`jdtls`) | `1.60.0` (build `202606262232`) | `JDTLS_VERSION` / `JDTLS_BUILD`; tarball **SHA-256**-verified |
| google-java-format | `1.36.1` | `GJF_VERSION`; all-deps jar **SHA-256**-verified |
| Neovim plugins | — | baked headless at build time from the dotfiles' own `lazy-lock.json` |

Maven, Gradle, jdtls, and google-java-format are fetched and verified
in a separate `toolchain` stage; only the relocatable prefix
(`/opt/langdev/toolchain`) is copied into the final image, so the fetch
tooling never reaches the runtime layer. The JDK is the one genuine
runtime dependency and is installed directly from Alpine's musl
OpenJDK.

Two details follow from the hardened runtime:

- **jdtls writes to a tmpfs, not the rootfs.** On the read-only root
  filesystem, the Eclipse JDT server uses its bundled `config_linux` as
  a **read-only shared** Eclipse configuration and writes its per-project
  workspace and per-user configuration under `$XDG_CACHE_HOME/jdtls`
  (a `tmpfs`). A small POSIX-sh launcher on `PATH` wires this up, so the
  runtime needs no Python.
- **The memory ceiling is 4g, not the suite default 2g.** The JVM,
  Maven, and — especially — the Gradle daemon and jdtls each index into
  a JVM of their own. The 2g default other suite images use starves
  real builds, so `compose.yaml` raises `mem_limit` to `4g` (with swap
  disabled). Raise it further for large multi-module builds.

Bumping the JDK pin: the exact `openjdk21` build floats within the
Alpine v3.22 repo as security updates land. If a build fails because
the pinned package was superseded, look up the current version
(`docker run --rm alpine:3.22 apk list openjdk21`) and update both the
`apk add` line in the `Containerfile` and the table above.

### The developer environment IS your dotfiles

javadev does **not** ship a synthetic shell or editor config. At build
time it clones the user's chezmoi-managed **dotfiles repo** and runs
`chezmoi apply`, so the container has the *real* bashrc, aliases, tmux
config, and Neovim setup — **latest `main`** by default. Pin
`DOTFILES_REF` to a tag or commit for a reproducible build (the applied
commit is recorded at `~/.dotfiles.commit` inside the image).

- **tmux** is installed and **loaded by default**: the entrypoint
  attaches to (or creates) a persistent `langdev` tmux session for
  interactive shells. Opt out with `LANGDEV_NO_TMUX=1`.
- The dotfiles' Neovim config is authoritative. javadev drops **one**
  `nvim/plugins.local/lang.lua` spec into the dotfiles' nvim
  (auto-imported via its `plugins.local` convention) to wire the Java
  LSP through `nvim-lspconfig` against the build-time `jdtls` launcher.
  The `java` Treesitter grammar is added on top of the dotfiles' set.
  Plugins are baked headless at build time and **Mason is left
  disabled**, so the container needs **no network on first launch** and
  stays reproducible.
- The Java `PATH`/env and tool aliases (`j`, `jc`, `mvnci`, `gw`,
  `gjf`, …) live in `dotfiles.d/java.sh`, installed root-owned (`0644`)
  to `/etc/profile.d/java.sh` and sourced by login shells — kept **out**
  of the user's dotfiles so those stay pristine and langdev-agnostic.
  The same `JAVA_HOME` / `MAVEN_HOME` / `GRADLE_HOME` / `PATH` are baked
  as `ENV` so non-login one-shot commands resolve the toolchain too.

---

## Security model

The full threat model and the private disclosure process are in
[`SECURITY.md`](SECURITY.md).

- **Non-root.** Runs as `dev` (UID/GID 1000); no `sudo`, no setuid
  binaries (setuid/setgid bits are stripped at build; `/tmp` is `1777`,
  sticky — not `777`).
- **Least privilege at runtime.** `compose.yaml` enforces
  `cap_drop: [ALL]`, `security_opt: [no-new-privileges:true]`,
  `read_only: true` (with `tmpfs` for `/tmp`, `/home/dev/.cache` where
  jdtls and Gradle write, and `/home/dev/.local/state`), `init: true`,
  `pids_limit: 512`, `mem_limit: 4g`, and `cpus: 2.0`. `make up` applies
  the same flags on the CLI.
- **No exposed ports.** This is a local dev shell, not a service.
- **Pinned, checksummed inputs.** Base image pinned **by digest**; the
  OpenJDK apk build version-pinned; Maven (SHA-512), Gradle, jdtls, and
  google-java-format (SHA-256) all **checksum-verified** against their
  upstream publishers — never `curl | sh`.
- **No committed secrets.** No `.env` is committed or `COPY`'d into an
  image — secrets are runtime-only via compose `env_file`. `.env` is
  both gitignored and dockerignored. javadev needs no secrets to build
  or run.
- **CI gates every change.** `hadolint`, `shellcheck`, a Docker build,
  and a Trivy image scan (fail on HIGH/CRITICAL) run on every push and
  pull request; a CycloneDX SBOM is uploaded as an artifact.

Report a vulnerability privately — see [`SECURITY.md`](SECURITY.md). Do
not open a public issue.

---

## Portability

- **One `Containerfile` (OCI).** `docker build`, `podman build`,
  `buildah`, and `nerdctl` all work from the same file.
- **Engine autodetection.** The `Makefile` detects `docker` or `podman`
  and adds `:Z` SELinux mount flags for Podman accordingly.
- **Multi-arch.** Builds for `linux/amd64` and `linux/arm64`: Alpine
  publishes `openjdk21` for both, and Maven, Gradle, and jdtls are
  pure-JVM (arch-independent).
- **No host assumptions.** The only bind mount is your project
  directory at `/work`.

---

## When not to use javadev

Stated plainly, so you can rule it out fast:

- **You need a production runtime image.** javadev builds a
  *development* environment — editor, LSP, build tools, a shell. It is
  deliberately not a minimal production artifact; ship a separate,
  slimmer JRE-based image for that.
- **You depend on a HotSpot/glibc-specific build.** The JDK here is
  Alpine's **musl-native** OpenJDK. That is the right choice for a small,
  self-consistent image, but if your workload needs a glibc JDK or a
  vendor-specific distribution, this is not it.
- **You do not use chezmoi-managed dotfiles.** The environment *is* the
  user's dotfiles. Without a chezmoi dotfiles repo you lose the main
  point, though the hardening and Java toolchain layers still stand on
  their own.
- **You need GPU passthrough or host-device access.** The default
  posture drops all capabilities and forbids privilege escalation.
  Device access requires deliberate, documented relaxations that run
  against the grain of the design.
- **You are on a platform without Docker or Podman.** There is no
  VM-less fallback; javadev targets an OCI engine on Linux, macOS, or
  Windows/WSL2.

---

## Development

The per-repo `Makefile` exposes the lifecycle; it auto-detects `docker`
or `podman` so the same commands work with either engine.

```sh
make up          # build + interactive dev shell (alias: make shell)
make run CMD=… # one-shot command in a fresh container
make build       # build the image for the host arch
make buildx      # multi-arch build (linux/amd64, linux/arm64)
make lint        # hadolint the Containerfile + shellcheck the scripts
make scan        # Trivy vulnerability scan (fail on HIGH/CRITICAL)
make sbom        # CycloneDX SBOM via syft
make trash       # remove the image and dangling build cache
make sync-common # refresh common/ from the langdev source
```

CI (`.github/workflows/ci.yml`) runs the lint and build/scan jobs on
every push and pull request. Contributions require signed commits and
Conventional Commit messages — see [`CONTRIBUTING.md`](CONTRIBUTING.md).

---

## Documentation

| Document | What it covers |
|---|---|
| [`CONTRIBUTING.md`](CONTRIBUTING.md) | The container workflow: build/lint/scan/sbom, signed commits, Conventional Commits. |
| [`SECURITY.md`](SECURITY.md) | The container threat model and the private disclosure process. |
| [`GOVERNANCE.md`](GOVERNANCE.md) | Who decides what, and how the maintainer base is meant to grow. |
| [`SUPPORT.md`](SUPPORT.md) | Where to go for questions, bugs, and feature requests. |
| [`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md) | Community standards and enforcement. |
| [`CHANGELOG.md`](CHANGELOG.md) | Notable changes, Keep a Changelog format. |

The suite house style every `langdev` README follows lives in
[`langdev/STYLE.md`](https://github.com/sebastienrousseau/langdev/blob/main/STYLE.md).

---

## License

Licensed under either of

- Apache License, Version 2.0 ([`LICENSE-APACHE`](LICENSE-APACHE))
- MIT license ([`LICENSE-MIT`](LICENSE-MIT))

at your option. The suite is dual-licensed `Apache-2.0 OR MIT`; every
file carries an `SPDX-License-Identifier: Apache-2.0 OR MIT` header.

Unless you explicitly state otherwise, any contribution intentionally
submitted for inclusion in the work by you, as defined in the Apache-2.0
license, shall be dual licensed as above, without any additional terms
or conditions.

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

- [Quick start](#quick-start) — clone, `make up`, and you are in a dev shell
- [Why this approach?](#why-this-approach) — the choices that shape the image

**What you get**

- [What's inside](#whats-inside) — the pinned toolchain, exactly
- [The developer environment IS your dotfiles](#the-developer-environment-is-your-dotfiles) — no synthetic config, tmux loaded by default

**Operational**

- [Security model](#security-model) — the container threat model and controls
- [Portability](#portability) — engines, architectures, host assumptions
- [When not to use javadev](#when-not-to-use-javadev) — limitations, stated plainly
- [Development](#development) — `make` targets, tests, lint, scan, SBOM, CI
- [Documentation](#documentation) — community docs and the house style
- [License](#license)

---

## Quick start

`javadev` is standalone. Clone it, and one command gets you an
interactive, hardened Java shell in a fresh container:

```sh
git clone https://github.com/sebastienrousseau/javadev.git
cd javadev
make up                        # build (if needed) + interactive dev shell
```

Other everyday commands:

```sh
make run CMD="mvn -version"    # one-shot command in a fresh container
make trash                     # remove the image + dangling build cache
```

Your project directory is the **only** bind mount, at `/work`.
Everything else is ephemeral (read-only rootfs + tmpfs), so a container
is truly disposable. No registry pull and no network are needed on first
launch — the image, including the Neovim plugin set, is built entirely
from the repo you cloned.

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
   Docker, Podman, Buildah, and nerdctl. The `Makefile` auto-detects the
   engine and adjusts flags (SELinux `:Z` mounts) accordingly. The image
   is multi-arch (`linux/amd64`, `linux/arm64`) — Alpine ships
   `openjdk21` for both, and Maven, Gradle, and jdtls are pure-JVM. The
   only bind mount is your project at `/work`, and `make trash` leaves
   nothing behind.

4. **Reliable and reproducible.** Everything is pinned: the base image
   **by digest**, the OpenJDK apk build by version, and every
   downloaded build tool **checksum-verified** — Maven by SHA-512,
   Gradle, jdtls, and google-java-format by SHA-256. There is no
   `curl | sh` anywhere in the build. Pin `DOTFILES_REF` to a tag or
   commit and a build is byte-reproducible.

Everything language-agnostic — the entrypoint, dotfiles bootstrap, and
`Containerfile`/`compose`/`Makefile` shape — is **vendored** from the
langdev core under `common/` and refreshed with `make sync-common`.
javadev is therefore a complete, auditable unit on its own, with no
base-image drift and no supply-chain hop at build time.

---

## What's inside

Every runtime input is pinned, and every downloaded input is
checksum-verified against its upstream publisher before it is used.

| Component | Version | How it's pinned |
|---|---|---|
| Alpine base | `3.22` | by digest `sha256:14358309…695dce` |
| OpenJDK (musl, LTS) | `21.0.11_p10-r0` | `apk add openjdk21=<ver>` from the digest-locked v3.22 repo |
| Apache Maven | `3.9.16` | `MAVEN_VERSION`; tarball **SHA-512**-verified against `downloads.apache.org` |
| Gradle | `9.7.1` | `GRADLE_VERSION`; `-bin.zip` **SHA-256**-verified against `services.gradle.org` |
| Eclipse JDT LS (`jdtls`) | `1.60.0` (build `202606262232`) | `JDTLS_VERSION` / `JDTLS_BUILD`; tarball **SHA-256**-verified |
| google-java-format | `1.36.1` | `GJF_VERSION`; all-deps jar **SHA-256**-verified |
| Dotfiles | latest | `DOTFILES_REF` build arg (default `main`; pin for reproducible builds) |
| Neovim plugins | — | baked headless at build time from the dotfiles' `lazy-lock.json` |

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

---

## The developer environment IS your dotfiles

javadev does **not** ship a synthetic shell or editor config. At build
time it clones the user's chezmoi-managed **dotfiles repo** and runs
`chezmoi apply`, so the container has the *real* bashrc, aliases, tmux
config, and Neovim setup — **always the latest** by default. Pin
`DOTFILES_REF` to a tag or commit for a reproducible build; the exact
commit bundled is recorded at `~/.dotfiles.commit`.

- **tmux is installed and loaded by default.** An interactive shell
  attaches to (or creates) a persistent `langdev` tmux session, so panes
  and windows survive detach. Opt out with `LANGDEV_NO_TMUX=1`.
- **The dotfiles' Neovim config is authoritative.** javadev drops
  exactly one `nvim/plugins.local/lang.lua` spec into the config's
  `plugins.local/` directory (auto-imported via that convention), so it
  composes with the rest of your setup untouched.
- **LSP via `nvim-lspconfig`.** Java is wired through `nvim-lspconfig`
  against the build-time `jdtls` launcher on `PATH` — Mason is left
  disabled, so there is no network on first launch. The `java`
  Treesitter grammar is added on top of the dotfiles' set.
- **Baked, offline-ready.** The full plugin set (yours plus this spec)
  is baked headless at build time from your dotfiles'
  `nvim/lazy-lock.json`, so the container is reproducible and needs no
  network on first launch.

The Java `PATH`/env and tool aliases (`j`, `jc`, `mvnci`, `gw`, `gjf`,
…) live in `dotfiles.d/java.sh`, installed root-owned (`0644`) to
`/etc/profile.d/java.sh` and sourced by login shells — kept **out** of
the user's dotfiles so those stay pristine and langdev-agnostic. The
same `JAVA_HOME` / `MAVEN_HOME` / `GRADLE_HOME` / `PATH` are baked as
`ENV` so non-login one-shot commands resolve the toolchain too.

---

## Security model

The full threat model and the private disclosure process are in
[`SECURITY.md`](SECURITY.md). Enforced by `compose.yaml` and mirrored in
`make run` / `make shell`:

- **Non-root.** Runs as `dev` (UID/GID 1000); no `sudo`, no setuid
  binaries — setuid/setgid bits are stripped at build; `/tmp` is `1777`,
  sticky — not `777`.
- **Least privilege at runtime.** `cap_drop: [ALL]`,
  `security_opt: [no-new-privileges:true]`, `read_only: true` (with
  `tmpfs` for `/tmp`, `/home/dev/.cache` where jdtls and Gradle write,
  and `/home/dev/.local/state`), and `init: true`.
- **Resource limits.** `pids_limit: 512`, `mem_limit: 4g`, `cpus: 2.0`
  (raised from the langdev default of 2g because the JVM, Gradle daemon,
  and jdtls are memory-hungry).
- **No exposed ports.** This is a local dev shell, not a service.
- **Pinned, checksummed inputs.** Base image pinned **by digest**; the
  OpenJDK apk build version-pinned; Maven (SHA-512), Gradle, jdtls, and
  google-java-format (SHA-256) all **checksum-verified** against their
  upstream publishers — never `curl | sh`.
- **No committed secrets.** No `.env` is committed or `COPY`'d into an
  image — secrets are runtime-only via compose `env_file`. `.env` is
  gitignored **and** dockerignored. javadev needs no secrets to build or
  run.
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
  and adjusts flags (SELinux `:Z` mounts) accordingly.
- **Multi-arch.** Images build for `linux/amd64` and `linux/arm64`:
  Alpine publishes `openjdk21` for both, and Maven, Gradle, and jdtls
  are pure-JVM (arch-independent).
- **No host assumptions.** The only bind mount is your project directory
  at `/work`.

---

## When not to use javadev

Stated plainly, so you can rule it out fast:

- **You need a production runtime image.** javadev builds a
  *development* environment — editor, LSP, build tools, a shell. It is
  deliberately not a minimal production artifact; ship a separate,
  slimmer JRE-based image for that.
- **You do not use chezmoi-managed dotfiles.** The environment *is* the
  user's dotfiles. Without a chezmoi dotfiles repo you lose the main
  point, though the hardening and Java toolchain layers still stand on
  their own.
- **You depend on a HotSpot/glibc-specific build.** The JDK here is
  Alpine's **musl-native** OpenJDK. That is the right choice for a
  small, self-consistent image, but if your workload needs a glibc JDK
  or a vendor-specific distribution, this is not it.
- **You need GPU passthrough or host-device access.** The default
  posture drops all capabilities and forbids privilege escalation.
  Workloads that need device access require deliberate, documented
  relaxations that run against the grain of the design.
- **You are on a platform without Docker or Podman.** There is no
  VM-less fallback; javadev targets an OCI engine on Linux, macOS, or
  Windows/WSL2.

---

## Development

The `Makefile` exposes the full lifecycle and auto-detects `docker` or
`podman` (adding `:Z` SELinux mount flags for Podman), so the same
commands work with either engine:

```sh
make up          # build + interactive dev shell (alias: make shell)
make run CMD=…   # one-shot command in a fresh container
make build       # build the image for the host arch
make buildx      # multi-arch build (linux/amd64, linux/arm64)
make lint        # hadolint the Containerfile + shellcheck the scripts
make scan        # Trivy vulnerability scan (fail on HIGH/CRITICAL)
make sbom        # CycloneDX SBOM via syft
make trash       # remove the image and dangling build cache
make sync-common # refresh common/ from the langdev source
```

### Tests and coverage

The language-agnostic shell core — `common/bootstrap-dotfiles.sh` and
`common/entrypoint.sh` — is vendored verbatim from the
[`langdev`](https://github.com/sebastienrousseau/langdev) core and
refreshed with `make sync-common`. That core is unit-tested with
[bats-core](https://github.com/bats-core/bats-core) under
[kcov](https://github.com/SimonKagstrom/kcov) in the langdev repo, whose
`make test` / `make coverage` gate **fails below 95 % line coverage**.
The tests are hermetic — `git`, `chezmoi`, `nvim`, `tmux`, and `rsync`
are test doubles on a closed `PATH`, so no network or container is
needed. The suite and its coverage gate are documented in
[langdev's `test/README.md`](https://github.com/sebastienrousseau/langdev/blob/main/test/README.md).

### CI and security workflows

This repo's [`.github/workflows/ci.yml`](.github/workflows/ci.yml) gates
every push and pull request with `hadolint`, `shellcheck`, a Docker
build, a Trivy image scan (fail on HIGH/CRITICAL), and a CycloneDX SBOM
artifact. The suite's OpenSSF hardening workflows are maintained in the
langdev core and provisioned across the suite from
[`templates/github-workflows/`](https://github.com/sebastienrousseau/langdev/tree/main/templates/github-workflows):

| Workflow | What it gates |
|---|---|
| `ci.yml` | shellcheck, hadolint, Docker build, Trivy image scan (fail HIGH/CRITICAL), CycloneDX SBOM |
| `scorecard.yml` | OpenSSF Scorecard, results published + SARIF to code-scanning |
| `sast.yml` | ShellCheck + Trivy config + Checkov, SARIF → code-scanning |
| `dependency-review.yml` | dependency + action changes reviewed on every PR |

The OpenSSF Best-Practices self-assessment lives in the langdev core's
[`doc/CII-BEST-PRACTICES.md`](https://github.com/sebastienrousseau/langdev/blob/main/doc/CII-BEST-PRACTICES.md);
a maintainer can apply the branch-protection ruleset with langdev's
[`scripts/set-branch-protection.sh`](https://github.com/sebastienrousseau/langdev/blob/main/scripts/set-branch-protection.sh).

Contributions require signed commits and Conventional Commit messages —
see [`CONTRIBUTING.md`](CONTRIBUTING.md).

---

## Documentation

| Document | What it covers |
|---|---|
| [`CONTRIBUTING.md`](CONTRIBUTING.md) | The container workflow: build/test/lint/scan/sbom, signed commits, Conventional Commits. |
| [`SECURITY.md`](SECURITY.md) | The container threat model and the private disclosure process. |
| [`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md) | Community standards and enforcement. |
| [`GOVERNANCE.md`](GOVERNANCE.md) | Who decides what, and how the maintainer base is meant to grow. |
| [`SUPPORT.md`](SUPPORT.md) | Where to go for questions, bugs, and feature requests. |
| [`CHANGELOG.md`](CHANGELOG.md) | Notable changes, Keep a Changelog format. |
| [langdev `doc/CII-BEST-PRACTICES.md`](https://github.com/sebastienrousseau/langdev/blob/main/doc/CII-BEST-PRACTICES.md) | OpenSSF Best-Practices self-assessment for the suite. |

javadev follows the langdev suite's house style — see
[`STYLE.md`](https://github.com/sebastienrousseau/langdev/blob/main/STYLE.md)
in the `langdev` core.

---

## License

Licensed under either of

- Apache License, Version 2.0 ([`LICENSE-APACHE`](LICENSE-APACHE))
- MIT license ([`LICENSE-MIT`](LICENSE-MIT))

at your option. The suite is dual-licensed `Apache-2.0 OR MIT`; every
non-vendored file carries an `SPDX-License-Identifier: Apache-2.0 OR MIT`
header.

Unless you explicitly state otherwise, any contribution intentionally
submitted for inclusion in the work by you, as defined in the Apache-2.0
license, shall be dual licensed as above, without any additional terms
or conditions.

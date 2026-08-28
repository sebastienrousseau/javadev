<!-- SPDX-License-Identifier: MIT -->

# javadev — portable, disposable Java development environment

`javadev` is a member of the [`langdev`](../../dockerfile/langdev) suite:
a complete, batteries-included Java toolchain inside a container you can
**spin up and throw away in seconds** — on any machine with Docker or
Podman (Linux, macOS, Windows/WSL2).

It ships Alpine's **musl-native OpenJDK 21 (LTS)** plus pinned **Maven**
and **Gradle**, with the Java LSP wired to a build-time **Eclipse JDT
Language Server** and **google-java-format**. No network is needed on
first launch.

The developer environment **is the user's own chezmoi-managed dotfiles**
(shell, aliases, **tmux**, Neovim) — cloned and applied at build time
(latest by default; pin with the `DOTFILES_REF` build arg). javadev adds
only a thin Java toolchain and a single `nvim/plugins.local/lang.lua` LSP
spec that the dotfiles' Neovim auto-imports. **tmux is loaded by
default** (the entrypoint attaches to a persistent `langdev` session; opt
out with `LANGDEV_NO_TMUX=1`).

## Quick start

```sh
make up            # build (if needed) + drop into an interactive dev shell
make run CMD="mvn -version"   # one-shot command in a fresh container
make trash         # remove the image + dangling build cache
```

Your code is the **only** bind mount, at `/work`. Everything else is
ephemeral (read-only rootfs + tmpfs), so a container is truly disposable.

## What's inside (pinned)

| Component | Version | How it's pinned |
|---|---|---|
| Alpine base | `3.22` | by digest `sha256:14358309…695dce` |
| OpenJDK (musl, LTS) | `21.0.11_p10-r0` | `apk add openjdk21=<ver>` from the digest-locked v3.22 repo |
| Apache Maven | `3.9.16` | `MAVEN_VERSION`; tarball **sha512**-verified against `downloads.apache.org` |
| Gradle | `9.7.1` | `GRADLE_VERSION`; `-bin.zip` **sha256**-verified against `services.gradle.org` |
| Eclipse JDT LS (`jdtls`) | `1.60.0` (build `202606262232`) | `JDTLS_VERSION`/`JDTLS_BUILD`; tarball **sha256**-verified |
| google-java-format | `1.36.1` | `GJF_VERSION`; all-deps jar **sha256**-verified |
| Dotfiles (shell/tmux/nvim) | latest `main` | `DOTFILES_REPO`/`DOTFILES_REF` build args; pin a tag/commit for reproducible builds |
| Neovim plugins | — | baked headless at build time from the dotfiles' own `lazy-lock.json` |

The build tools and LSP are fetched + checksum-verified in a separate
`toolchain` stage; only the relocatable prefix (`/opt/langdev/toolchain`)
is copied into the final image — `curl`, `unzip` and other fetch tooling
never reach the runtime layer. The JDK is the one genuine runtime
dependency and is installed directly from Alpine's musl OpenJDK.

> **Dotfiles & reproducibility:** the shell/tmux/Neovim config is cloned
> from the user's chezmoi dotfiles repo at build time — **latest `main`**
> by default. For a fully reproducible image, pin the exact commit with
> `--build-arg DOTFILES_REF=<sha>` (the applied commit is also recorded at
> `~/.dotfiles.commit` inside the image). The Neovim plugin set is baked
> headless during the build, so first launch needs no network.

> **Bumping the JDK pin:** the exact `openjdk21` build floats within the
> Alpine v3.22 repo as security updates land. If a build fails because the
> pinned package was superseded, look up the current version
> (`docker run --rm alpine:3.22 apk list openjdk21`) and update both the
> `apk add` line in the `Containerfile` and the table above.

## Make targets

| Target | Description |
|---|---|
| `make up` / `make shell` | Build then start an interactive dev shell |
| `make run CMD="…"` | Run a one-shot command in a fresh container |
| `make build` | Build the image for the host arch |
| `make buildx` | Build a multi-arch image (`linux/amd64,linux/arm64`) |
| `make trash` | Remove the image and dangling build cache |
| `make lint` | `hadolint` the Containerfile + `shellcheck` the scripts |
| `make scan` | Trivy vulnerability scan (HIGH/CRITICAL) of the built image |
| `make sbom` | Generate a CycloneDX SBOM (`sbom.cdx.json`) via syft |
| `make sync-common` | Refresh `common/` from the langdev source |

The `Makefile` auto-detects `docker` or `podman` (adding `:Z` SELinux
mount flags for Podman) so the same commands work with either engine.

## Aliases

Language-agnostic aliases and shell setup come from the **user's own
dotfiles** (applied at build time). The Java-specific fragment
`dotfiles.d/java.sh` is installed root-owned (`0644`) to
`/etc/profile.d/java.sh`, so it is sourced by login shells via
`/etc/profile` — kept OUT of the user's dotfiles so those stay pristine.

### Java (`/etc/profile.d/java.sh`)

| Alias | Expands to |
|---|---|
| `j` | `java` |
| `jc` | `javac` |
| `mvnci` | `mvn clean install` |
| `mvnt` | `mvn test` |
| `gw` | `gradle` |
| `gwb` | `gradle build` |
| `gwt` | `gradle test` |
| `gjf` | `google-java-format` |

`java.sh` also exports `JAVA_HOME`, `MAVEN_HOME`, `GRADLE_HOME` and
prepends the JDK, Maven, Gradle and toolchain-launcher `bin` dirs to
`PATH` (idempotently). It does **not** propagate any host `PATH`. The same
`JAVA_HOME`/`MAVEN_HOME`/`GRADLE_HOME`/`PATH` are also baked as `ENV` in
the Containerfile so non-login one-shot commands (e.g.
`make run CMD="mvn -version"`) resolve the toolchain too.

## Neovim

- The Neovim config is the **user's own dotfiles' nvim** (applied at build
  time); it is authoritative. javadev drops **one** spec,
  `nvim/plugins.local/lang.lua`, into the dotfiles' `plugins.local`
  convention (auto-imported) to wire the Java LSP. Plugins are baked
  headless at build time, so first launch needs no network.
- Java is configured through `nvim-lspconfig` in
  `nvim/plugins.local/lang.lua`, pointed at the build-time `jdtls`
  launcher on `PATH`. For a richer experience (test/debug codelenses,
  refactors) swap in `mfussenegger/nvim-jdtls` against the same launcher.
- Treesitter grammar `java` is added on top of the dotfiles' set.
- **Mason is left disabled** — the LSP is installed at build time, so
  first launch needs no network and the image stays reproducible.

`jdtls` runs against the pre-installed JDK via a small POSIX-sh launcher
(no Python needed). On the read-only rootfs it uses the bundled
`config_linux` as a read-only shared Eclipse configuration and writes its
per-project workspace/config under `$XDG_CACHE_HOME/jdtls` (a tmpfs).

## Security posture

Enforced by `compose.yaml` (and mirrored in `make run`/`make shell`):

- Runs as non-root `dev` (UID/GID `1000`); no `sudo`, no setuid binaries
  (setuid/setgid bits stripped at build; `/tmp` is `1777`, sticky — not `777`).
- `read_only: true` root filesystem, with tmpfs for `/tmp`,
  `/home/dev/.cache` (where jdtls and Gradle write), `/home/dev/.local/state`.
- `cap_drop: [ALL]`, `security_opt: [no-new-privileges:true]`, `init: true`.
- Resource limits: `pids_limit: 512`, **`mem_limit: 4g`**, `cpus: 2.0`.
  The JVM, Maven and (especially) the Gradle daemon and jdtls are
  memory-hungry — the 2g default used by other suite images starves real
  builds, so javadev raises the ceiling to 4g (see `compose.yaml` for the
  rationale; raise it further for large multi-module builds).
- **No exposed ports** — this is a local dev shell, not a service.
- The **only** bind mount is your project directory at `/work`.
- Base image pinned by digest; Maven (sha512), Gradle (sha256), jdtls
  (sha256) and google-java-format (sha256) are all checksum-verified
  against their upstream publishers; the OpenJDK apk build is version-pinned.
- No `.env` is committed or `COPY`'d into an image — secrets are
  runtime-only via compose `env_file`. `.env` is gitignored **and**
  dockerignored. `javadev` needs no secrets to build or run.

## Portability

One OCI `Containerfile` builds with `docker build`, `podman build`,
`buildah`, or `nerdctl`, for `linux/amd64` and `linux/arm64`. Alpine
publishes `openjdk21` for both arches and Maven/Gradle/jdtls are
pure-JVM (arch-independent), so the image is fully multi-arch. No
host-path assumptions beyond the `/work` bind mount.

## CI

`.github/workflows/ci.yml` gates every change with `hadolint`,
`shellcheck`, a Docker build, a Trivy scan (fails on HIGH/CRITICAL), and
uploads a CycloneDX SBOM artifact.

## License

MIT — see [`LICENSE`](LICENSE).

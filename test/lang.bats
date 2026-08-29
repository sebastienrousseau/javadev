#!/usr/bin/env bats
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Unit tests for dotfiles.d/java.sh — the Java language profile fragment
# installed to /etc/profile.d and sourced by login shells. The fragment exports
# JAVA_HOME/MAVEN_HOME/GRADLE_HOME and prepends the toolchain bins to PATH
# (guarded, so it is safe to re-source). These tests source it in a hermetic
# sandbox and assert it sets that environment without error and is idempotent.
load helpers/common

setup() { common_setup; }

SCRIPT="dotfiles.d/java.sh"

@test "java.sh: sets the toolchain env and prepends the JDK/build bins to PATH" {
  run bash -c '
    set -euo pipefail
    export PATH="/langdev-base"
    # shellcheck source=/dev/null
    source "$1"
    printf "JAVA_HOME=%s\n" "$JAVA_HOME"
    printf "MAVEN_HOME=%s\n" "$MAVEN_HOME"
    printf "GRADLE_HOME=%s\n" "$GRADLE_HOME"
    printf "PATHVAL=%s\n" "$PATH"
  ' _ "$REPO_ROOT/$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"JAVA_HOME=/usr/lib/jvm/java-21-openjdk"* ]]
  [[ "$output" == *"MAVEN_HOME=/opt/langdev/toolchain/maven"* ]]
  [[ "$output" == *"GRADLE_HOME=/opt/langdev/toolchain/gradle"* ]]
  [[ "$output" == *"/usr/lib/jvm/java-21-openjdk/bin"* ]]
}

@test "java.sh: is idempotent — re-sourcing does not duplicate the PATH entry" {
  run bash -c '
    set -euo pipefail
    export PATH="/langdev-base"
    source "$1"; source "$1"
    printf "PATHVAL=%s" "$PATH"
  ' _ "$REPO_ROOT/$SCRIPT"
  [ "$status" -eq 0 ]
  pathval="${output#PATHVAL=}"
  n="$(printf '%s' "$pathval" | grep -oF '/usr/lib/jvm/java-21-openjdk/bin' | wc -l)"
  [ "$n" -eq 1 ]
}

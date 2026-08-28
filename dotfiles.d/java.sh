# ~/.bashrc.d/java.sh — Java language fragment (javadev)
# SPDX-License-Identifier: MIT
#
# Sourced by the common ~/.bashrc for interactive shells. Sets the Java
# environment for the pre-installed, musl OpenJDK plus the relocatable Maven /
# Gradle / jdtls / google-java-format toolchain, and adds a few aliases ONLY
# for tools that are actually installed in the image (java, javac, mvn,
# gradle). No host PATH is propagated.

# musl OpenJDK (installed via apk) + relocatable build tools (copied prefix).
export JAVA_HOME=/usr/lib/jvm/java-21-openjdk
export MAVEN_HOME=/opt/langdev/toolchain/maven
export GRADLE_HOME=/opt/langdev/toolchain/gradle

# Prepend the toolchain bins (jdk/bin, toolchain/bin launchers, maven/bin,
# gradle/bin) without clobbering or duplicating the existing PATH.
for _jd_dir in \
  "${JAVA_HOME}/bin" \
  /opt/langdev/toolchain/bin \
  "${MAVEN_HOME}/bin" \
  "${GRADLE_HOME}/bin"; do
  case ":${PATH}:" in
    *":${_jd_dir}:"*) ;;
    *) export PATH="${_jd_dir}:${PATH}" ;;
  esac
done
unset _jd_dir

# --- Aliases (only for tools present in the image) ---------------------------
alias j='java'
alias jc='javac'
alias mvnci='mvn clean install'
alias mvnt='mvn test'
alias gw='gradle'
alias gwb='gradle build'
alias gwt='gradle test'
alias gjf='google-java-format'

-- javadev — Java language wiring for Neovim (langdev lang.lua)
-- SPDX-License-Identifier: MIT
--
-- The Eclipse JDT Language Server (jdtls) is installed at BUILD time by the
-- toolchain stage and exposed on PATH via the `jdtls` launcher (a POSIX-sh
-- wrapper around the build-time JDK — no Python needed). Mason stays disabled
-- (see common/nvim/plugins/disabled.lua): no network on first launch, fully
-- reproducible.
--
-- We wire jdtls through nvim-lspconfig's `servers` table (LazyVim style),
-- overriding only `cmd` to point at the pre-installed launcher. This keeps the
-- config tiny and dependency-free. For a richer Java experience (test/debug
-- codelenses, organize-imports, extract refactors) swap this for
-- `mfussenegger/nvim-jdtls`, still pointed at the same `jdtls` launcher and
-- with Mason left disabled.
return {
  -- Treesitter grammar for Java (compiled at build time).
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      vim.list_extend(opts.ensure_installed, { "java" })
    end,
  },

  -- Eclipse JDT LS via nvim-lspconfig, pointed at the build-time launcher.
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        jdtls = {
          -- Never let LazyVim try to install this via Mason.
          mason = false,
          -- Build-time launcher on PATH (resolves its own JDK + workspace).
          cmd = { "jdtls" },
          -- Project roots common to Maven/Gradle/Eclipse layouts.
          root_dir = function(fname)
            local util = require("lspconfig.util")
            return util.root_pattern(
              "settings.gradle",
              "settings.gradle.kts",
              "build.gradle",
              "build.gradle.kts",
              "pom.xml",
              ".git"
            )(fname)
          end,
          settings = {
            java = {
              format = { enabled = true },
              signatureHelp = { enabled = true },
              contentProvider = { preferred = "fernflower" },
            },
          },
        },
      },
    },
  },
}

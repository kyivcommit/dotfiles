return {
  {
    "mfussenegger/nvim-lint",
    opts = {
      linters = {
        -- Disable markdownlint MD013 (line-length) via the config file.
        ["markdownlint-cli2"] = {
          args = { "--config", vim.fn.stdpath("config") .. "/.markdownlint-cli2.jsonc", "-" },
        },
      },
    },
  },
}

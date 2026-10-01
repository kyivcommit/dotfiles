-- return {
--   { "shaunsingh/nord.nvim" },
--   {
--     "LazyVim/LazyVim",
--     opts = { colorscheme = "nord" },
--   },
-- }

return {
  { "catppuccin/nvim", name = "catppuccin", priority = 1000 },
  {
    "LazyVim/LazyVim",
    opts = { colorscheme = "catppuccin-nvim" },
  },
}

-- return {
--   "everviolet/nvim",
--   name = "evergarden",
--   priority = 1000, -- Colorscheme plugin is loaded first before any other plugins
--   opts = {
--     theme = {
--       variant = "fall", -- 'winter'|'fall'|'spring'|'summer'
--       accent = "green",
--     },
--     editor = {
--       transparent_background = false,
--       sign = { color = "none" },
--       float = {
--         color = "mantle",
--         solid_border = false,
--       },
--       completion = {
--         color = "surface0",
--       },
--     },
--   },
-- }

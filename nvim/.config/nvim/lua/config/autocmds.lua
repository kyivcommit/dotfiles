-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

-- Remember system layout in insert; leaving insert -> ABC, returning -> restore.
-- Karabiner (Caps hold in terminals) switches to ABC *before* nvim sees the key, so its
-- shell_command saves the layout it replaced to STATE; we prefer that over the (already ABC) current one.
local IM, ENG = "/opt/homebrew/bin/im-select", "com.apple.keylayout.ABC"
local STATE = vim.fn.stdpath("cache") .. "/prev-im"
local saved

local function im(arg)
  local r = vim.system(arg and { IM, arg } or { IM }, { text = true }):wait()
  return vim.trim(r.stdout or "")
end
local function ins(m) return m:match("^[iR]") ~= nil end -- C-o gives "niI": starts with n

-- macOS only: skipped where im-select is absent (e.g. remote Linux servers)
if vim.fn.executable(IM) == 1 then
  vim.api.nvim_create_autocmd("ModeChanged", {
    callback = function()
      local o, n = vim.v.event.old_mode, vim.v.event.new_mode
      if ins(o) and not ins(n) then
        local cur = im()
        local f = io.open(STATE)
        local prev = f and vim.trim(f:read("*a") or "")
        if f then f:close() end
        os.remove(STATE)
        if cur ~= ENG then
          saved = cur
          im(ENG)
        else
          saved = prev ~= "" and prev or ENG
        end
      elseif ins(n) and not ins(o) then
        os.remove(STATE) -- drop stale Karabiner state
        if saved and saved ~= ENG then im(saved) end
      end
    end,
  })
end

vim.api.nvim_create_autocmd("FileType", {
  pattern = "markdown",
  callback = function()
    vim.opt_local.spell = false
  end,
})

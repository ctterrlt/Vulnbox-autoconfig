-- ====================================================================
-- NEVIM STARTER CONFIG
-- ====================================================================

-- Line Numbers (Absolute + Relative makes jumping lines with 'j' and 'k' easy)
vim.opt.number = true
vim.opt.relativenumber = true

-- System Clipboard Link
vim.opt.clipboard = "unnamedplus"

-- Tabs & Indentation (4 spaces)
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.expandtab = true
vim.opt.smartindent = true

-- Search settings
vim.opt.hlsearch = false   -- Don't keep words highlighted after searching
vim.opt.incsearch = true   -- Show search matches as you type

-- Enable Mouse
vim.opt.mouse = 'a'

-- Fast Updates
vim.opt.updatetime = 250

-- ====================================================================
-- CUSTOM SHORTCUTS
-- ====================================================================

-- 1. Ctrl + A to Select All
vim.keymap.set('n', '<C-a>', 'ggVG')
vim.keymap.set('v', '<C-a>', '<Esc>ggVG')
vim.keymap.set('i', '<C-a>', '<Esc>ggVG')

-- 2. Ctrl + C to Copy (Keeps the Highlight Active)
vim.keymap.set('x', '<C-c>', '"+ygv')

-- 3. Ctrl + D to Deselect / Clear Highlight
vim.keymap.set('x', '<C-d>', '<Esc>')

-- 4. Ctrl + V to Paste (Overwrites highlight if in Visual mode)
vim.keymap.set('n', '<C-v>', '"+p')
vim.keymap.set('i', '<C-v>', '<C-r>+')
vim.keymap.set('x', '<C-v>', '"+p')

-- 5. Ctrl + F to Search
vim.keymap.set('n', '<C-f>', '/')
vim.keymap.set('i', '<C-f>', '<Esc>/')
vim.keymap.set('x', '<C-f>', '<Esc>/')

-- 6. Ctrl + O to Save (Always Writes the file)
-- Works in Normal, Insert, and Visual modes without dropping your typing mode
vim.keymap.set({'n', 'i', 'x'}, '<C-o>', '<Cmd>write<CR>')

-- 7. Ctrl + X to Exit (Leaves Neovim)
vim.keymap.set({'n', 'i', 'x'}, '<C-x>', '<Cmd>quit<CR>')

-- 8. Delete / Backspace behavior when text is highlighted
-- This deletes the selection completely WITHOUT overwriting your clipboard
vim.keymap.set('x', '<Del>', '"_d')
vim.keymap.set('x', '<BS>', '"_d')

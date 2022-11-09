local cmdline = require('telescomp.cmdline')

local cmdline_builtin = require('telescomp.cmdline.builtin')
local set_keymap = vim.keymap.set
set_keymap('c', '<C-X><C-R>', cmdline_builtin.git_ref)
set_keymap('c', '<C-X><C-F>', cmdline_builtin.find_files)
set_keymap('c', '<C-X><C-M>', cmdline_builtin.menu)
set_keymap('c', '<C-X><C-X>', function()
  local opt = cmdline.spec_completer_options({ expand = true })
  local default_text = opt.default_text
  if string.match(default_text, '^%./') ~= nil then
    opt.default_text = string.gsub(default_text, '^%./', '')
    return cmdline_builtin.find_files({}, opt)
  end
  if string.match(default_text, '/') ~= nil then
    return cmdline_builtin.find_files({}, opt)
  end

  return cmdline_builtin.menu({}, opt)
end)

return {
  cmdline = cmdline,
}

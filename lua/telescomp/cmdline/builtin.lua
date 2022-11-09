local fn = vim.fn
local cmdline = require('telescomp.cmdline')

local M = {}

M.git_ref = cmdline.create_completer({
  opts = {
    finder = function()
      return {
        results = fn.split(fn.system(
          [[git for-each-ref --format="%(refname:short)"]]
        ), "\n"),
      }
    end
  }
})

M.find_files = cmdline.create_completer({
  picker = require('telescope.builtin').find_files
})

M.menu = cmdline.create_menu({ menu = M })

return M

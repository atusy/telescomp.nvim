local fn = vim.fn
local startswith = vim.startswith
local tbl_map = vim.tbl_map
local cmdline = require('telescomp.cmdline')
local utils = require('telescomp.utils')

local M = {}

local function getcompletion(opts_comp)
  local left = opts_comp.left
  local default_text = opts_comp.default_text
  local completion = fn.getcompletion(left .. default_text, 'cmdline')

  if startswith(left, 'set') and startswith(default_text, 'no') then
    return tbl_map(function(x) return 'no' .. x end, completion)
  end

  return completion
end

local function clean_pattern(x, y)
  if y == nil then return '' end
  local n = fn.strchars(x)
  if n == 0 then return x end
  for i = 0, n - 1 do
    if startswith(y, fn.strcharpart(x, i, n)) then
      return fn.strcharpart(x, 0, i)
    end
  end
  return x
end

local _complete = cmdline.create_completer({
  opts_picker = { finder = function() return { results = {} } end }
})

function M.cmdline(opts_picker, opts_comp)
  -- setup opts_comp
  opts_comp = cmdline.spec_completer_options(opts_comp)

  -- find candidates and setup opts_picker
  local results = getcompletion(opts_comp)
  opts_picker = utils.merge(
    { finder = require('telescope.finders').new_table({ results = results }) },
    opts_picker
  )

  -- update opts_comp
  if startswith(opts_comp.left, 'lua ') then
    opts_comp.left = opts_comp.left .. clean_pattern(opts_comp.default_text, results[1])
  end
  opts_comp.default_text = ''

  _complete(opts_picker, opts_comp)
end

M.find_files = cmdline.create_completer({
  picker = require('telescope.builtin').find_files
})

local formatters = setmetatable({
  git_branches = function(x) return x.value end,
  git_commits = function(x) return x.value end,
  git_status = function(x) return x.path end,
  lsp_workspace_symbols = function(x) return x.symbol_name end,
  lsp_document_symbols = function(x) return x.symbol_name end,
}, {
  __index = function(_, _)
    return function(x) return x[1] or x.value or x.path or x.filename end
  end
})

local function callable(x)
  if type(x) == 'function' then
    return true
  end
  if type(x) == 'table' then
    local meta = debug.getmetatable(x)
    return type(meta) == 'table' and type(meta.__call) == 'function'
  end
  return false
end

return setmetatable(M, {
  __index = function(self, key)
    if key == "builtin" then
      return function(...) return self(...) end
    end

    local formatter_one = formatters[key]
    local function formatter(tbl)
      -- vim.pretty_print(tbl[1])
      return table.concat(vim.tbl_map(formatter_one, tbl), ' ')
    end

    local picker = require('telescope.builtin')[key]

    if picker == nil then
      vim.notify("telescomp.cmdline.builtin." .. key .. " is not found", vim.log.levels.WARN)
      return function(_, _) end
    end

    return cmdline.create_completer({
      picker = picker,
      opts_completer = { formatter = formatter }
    })
  end,
  __call = function(self, ...)
    local menu = utils.copy(self)
    for k, v in pairs(require('telescope.builtin')) do
      if callable(v) and menu[k] == nil then
        menu[k] = self[k]
      end
    end
    cmdline.create_menu({ menu = menu })(...)
  end
})

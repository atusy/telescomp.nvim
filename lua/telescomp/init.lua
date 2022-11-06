local vim = vim
local M = {}
local set_keymap = vim.keymap.set


local action_state = require "telescope.actions.state"
local actions = require "telescope.actions"
local pickers = require "telescope.pickers"
local finders = require "telescope.finders"
local conf = require("telescope.config").values

local lhs = {
  colon = "<Plug>(telescomp-colon)",
  -- below are internals
  complete = "<Plug>(telescomp-complete)",
  normal = "<Plug>(telescomp-normal)",
}

local termcodes = vim.tbl_map(
  function(x) return vim.api.nvim_replace_termcodes(x, true, false, true) end,
  lhs
)

local function set_normal_mode()
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes([[<C-\><C-N>]], true, false, true), "tn", true)
end

local function complete(left, middle, right)
  -- disable remapping by invoking <Plug> mapping instead of feedkeys
  -- if user want to use own `:`, then map <Plug>(telescomp-colon)
  local cmdline = string.gsub(left .. middle .. right, "<", "<lt>")
  local setcmdpos = "<C-R><C-R>=setcmdpos(" .. (vim.fn.strlen(left .. middle) + 1) .. ")[-1]<CR>"
  local modes = { "n", "i", "c", "v", "x", "s", "o", "t", "l" }
  vim.keymap.set(modes, lhs.complete, [[<C-\><C-N>]] .. lhs.colon .. cmdline .. setcmdpos, { remap = false })
  vim.api.nvim_feedkeys(termcodes.complete, "t", true)
  -- vim.schedule(function() vim.keymap.del(modes, lhs.complete) end)
end

local function insert_selection(left, right, modifier)
  return function(prompt_bufnr, map)
    local _ = map
    local completed = false
    actions.select_default:replace(function()
      completed = true
      actions.close(prompt_bufnr)
      -- TODO: support multiple selections (cf. https://github.com/nvim-telescope/telescope.nvim/issues/1048#issuecomment-889122232 )
      local selection = action_state.get_selected_entry()
      complete(left, modifier and modifier(selection) or selection[1], right)
    end)
    actions.close:enhance({
      post = function()
        if not completed then
          complete(left, '', right)
        end
        return true
      end
    })
    return true
  end
end

function M.create_cmdline_completer(opts)
  local picker = opts.picker
  local opts_picker = {}
  for k, v in pairs(opts.opts or {}) do
    opts_picker[k] = v
  end
  local finder = opts_picker.finder

  return function()
    local curline = vim.fn.getcmdline()
    local curpos = vim.fn.getcmdpos() - 1
    local left = vim.fn.strpart(curline, 0, curpos)
    local right = vim.fn.strpart(curline, curpos)
    opts_picker.attach_mappings = insert_selection(left, right, opts.fn_modify_selection)
    set_normal_mode() -- Exit from cmdline happens on entering telescope ui, but do it manually for sure
    if picker then
      picker(opts_picker)
      return
    end
    opts_picker.previewer = opts_picker.previewer or false
    opts_picker.prompt_title = opts_picker.prompt_title or "Complete cmdline"
    opts_picker.finder = type(finder) == "function" and finders.new_table(finder()) or finder
    opts_picker.sorter = opts_picker.sorter or conf.generic_sorter({})
    pickers.new({}, opts_picker):find()
  end
end

M.builtin_cmdline_completer = {}
M.builtin_cmdline_completer.example = M.create_cmdline_completer({
  opts = { finder = finders.new_table({
    results = { 'a', '<ESC>' }
  }) }
})
M.builtin_cmdline_completer.git_ref = M.create_cmdline_completer({
  opts = {
    finder = function()
      return {
        results = vim.fn.split(vim.fn.system([[git for-each-ref --format="%(refname:short)"]]), "\n")
      }
    end
  }
})
M.builtin_cmdline_completer.find_files = M.create_cmdline_completer({ picker = require('telescope.builtin').find_files })

-- set_keymap('c', '<Plug>(test)', function() pcall(insert_ref) end)
set_keymap('c', '<Plug>(test)', M.builtin_cmdline_completer.find_files)
set_keymap('c', '<C-X><C-R>', function() pcall(M.builtin_cmdline_completer.git_ref) end)
set_keymap('c', '<C-X><C-F>', function() pcall(M.builtin_cmdline_completer.find_files) end)
set_keymap('n', '<Space><Space>', ':ab  cd<Left><Left><Left><Plug>(test)')
set_keymap('', '<Space>k', function() vim.pretty_print(vim.api.nvim_get_mode()) end)

function M.setup(opt)
  vim.keymap.set("n", lhs.colon, [[:]], { remap = false })
end

return M

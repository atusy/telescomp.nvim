local api = vim.api
local fn = vim.fn
local set_keymap = vim.keymap.set

local M = {}


local action_state = require 'telescope.actions.state'
local actions = require 'telescope.actions'
local pickers = require 'telescope.pickers'
local finders = require 'telescope.finders'
local conf = require('telescope.config').values

local plug = {
  colon = '<Plug>(telescomp-colon)',
}

local function replace_termcodes(x)
  return api.nvim_replace_termcodes(x, true, false, true)
end

local function feedkeys(x)
  api.nvim_feedkeys(x, 'n', false)
end

local function set_normal_mode()
  feedkeys(replace_termcodes([[<C-\><C-N>]]))
end

local function complete(left, middle, right)
  -- disable remapping by invoking <Plug> mapping instead of feedkeys
  -- if user want to use own `:`, then map <Plug>(telescomp-colon)
  local cmdline = string.gsub(left .. middle .. right, '<', '<lt>')
  local setcmdpos = '<C-R><C-R>=setcmdpos(' .. (fn.strlen(left .. middle) + 1) .. ')[-1]<CR>'
  feedkeys(replace_termcodes([[<C-\><C-N>]] .. plug.colon) .. cmdline .. replace_termcodes(setcmdpos))
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

local function copy(x)
  local ret = {}
  for k, v in pairs(x) do
    ret[k] = v
  end
  return ret
end

function M.create_completer(opts)
  local format_selection = opts.format_selection
  local picker = opts.picker
  local opts_picker = copy(opts.opts or {})
  local finder = opts_picker.finder
  opts_picker.finder = type(finder) == 'function' and finders.new_table(finder()) or finder

  return function(opts)
    local curline = opts.curline or fn.getcmdline()
    local curpos = opts.curpos or (fn.getcmdpos() - 1)
    local left = fn.strpart(curline, 0, curpos)
    local right = fn.strpart(curline, curpos)
    opts_picker.attach_mappings = insert_selection(left, right, format_selection)
    set_normal_mode() -- Exit from cmdline happens on entering telescope ui, but do it manually for sure
    if picker then
      picker(opts_picker)
      return
    end
    opts_picker.previewer = opts_picker.previewer or false
    opts_picker.prompt_title = opts_picker.prompt_title or 'Complete cmdline'
    opts_picker.sorter = opts_picker.sorter or conf.generic_sorter({})
    pickers.new({}, opts_picker):find()
  end
end

M.builtin = {}
M.builtin.git_ref = M.create_completer({
  opts = {
    finder = function()
      return {
        results = fn.split(fn.system([[git for-each-ref --format="%(refname:short)"]]), "\n"),
      }
    end
  }
})
M.builtin.find_files = M.create_completer({ picker = require('telescope.builtin').find_files })

-- set_keymap('c', '<Plug>(test)', function() pcall(insert_ref) end)
set_keymap('c', '<Plug>(test)', M.builtin.find_files)
set_keymap('c', '<C-X><C-R>', function() pcall(M.builtin.git_ref) end)
set_keymap('c', '<C-X><C-F>', function() pcall(M.builtin.find_files) end)
set_keymap('n', '<Space><Space>', ':ab  cd<Left><Left><Left><Plug>(test)')

function M.setup(opt)
  set_keymap('n', plug.colon, ':', { remap = false })
end

return M

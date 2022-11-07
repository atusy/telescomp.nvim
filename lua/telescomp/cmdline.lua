local fn = vim.fn
local set_keymap = vim.keymap.set

local M = {}


local action_state = require 'telescope.actions.state'
local utils = require 'telescomp.utils'
local copy = utils.copy
local merge = utils.merge
local replace_termcodes = utils.replace_termcodes
local feedkeys = utils.feedkeys

local actions = require 'telescope.actions'
local pickers = require 'telescope.pickers'
local finders = require 'telescope.finders'
local conf = require('telescope.config').values

local plug = {
  colon = '<Plug>(telescomp-colon)',
}

local function complete(left, middle, right)
  -- disable remapping by invoking <Plug> mapping instead of feedkeys
  -- if user want to use own `:`, then map <Plug>(telescomp-colon)
  local cmdline = string.gsub(left .. middle .. right, '<', '<lt>')
  local setcmdpos = '<C-R><C-R>=setcmdpos(' .. (fn.strlen(left .. middle) + 1) .. ')[-1]<CR>'
  feedkeys(replace_termcodes([[<C-\><C-N>]] .. plug.colon) .. cmdline .. replace_termcodes(setcmdpos))
  -- vim.schedule(function() vim.keymap.del(modes, lhs.complete) end)
end

local function insert_selection(left, middle, right, modifier)
  left = left or ''
  middle = middle or ''
  right = right or ''
  modifier = modifier or function(selection) return selection[1] end
  return function(prompt_bufnr, map)
    local _ = map
    local completed = false
    actions.select_default:replace(function()
      completed = true
      actions.close(prompt_bufnr)
      -- TODO: support multiple selections (cf. https://github.com/nvim-telescope/telescope.nvim/issues/1048#issuecomment-889122232 )
      local selection = action_state.get_selected_entry()
      complete(left, modifier(selection), right)
    end)
    actions.close:enhance({
      post = function()
        if not completed then
          complete(left, middle, right)
        end
        return true
      end
    })
    return true
  end
end

local function split_curline(curline, curpos, expand)
  curline = curline or fn.getcmdline()
  curpos = curpos or (fn.getcmdpos() - 1)
  local left = fn.strpart(curline, 0, curpos)
  local middle = ''
  local right = fn.strpart(curline, curpos)
  if expand then
    local matchlist = fn.matchlist(left, [[^\(.* \|\)\([^ ]\+\)$]])
    if #matchlist > 0 then
      left = matchlist[2]
      middle = matchlist[3]
    end
  end
  return left, middle, right
end

function M.create_completer(opts)
  local format_selection = opts.format_selection
  local picker = opts.picker
  local opts_picker_default = copy(opts.opts or {})
  local finder = opts_picker_default.finder
  opts_picker_default.finder = type(finder) == 'function' and finders.new_table(finder()) or finder

  return function(opts_picker, opts_comp)
    opts_comp = opts_comp or {}
    local left, middle, right = split_curline(
      opts_comp.curline,
      opts_comp.curpos,
      opts_comp.expand == false and false or true
    )

    opts_picker = merge(opts_picker_default, opts_picker)
    opts_picker.default_text = middle
    opts_picker.attach_mappings = insert_selection(left, middle, right, format_selection)

    -- set normal mode
    -- entering telescope ui infers it, but do it manually for sure
    feedkeys(replace_termcodes([[<C-\><C-N>]]))

    if picker then
      picker(opts_picker)
      return
    end

    pickers.new(
      {},
      merge({
        previewer = false,
        prompt_title = 'Complete cmdline',
        sortrer = conf.generic_sorter({})
      }, opts_picker)
    ):find()
  end
end

function M.create_menu(opts)
  local menu = opts.menu
  local menu_keys = {}
  for k, _ in pairs(opts.menu) do
    table.insert(menu_keys, k)
  end

  local opts_picker_default = merge({
    previewer = false,
    prompt_title = 'Complete cmdline',
    sorter = conf.generic_sorter({}),
    finder = finders.new_table({ results = menu_keys }),
  }, opts.opts)

  return function(opts_picker, opts_comp)
    opts_picker = merge(opts_picker_default, opts_picker)
    opts_comp = opts_comp or {}
    opts_comp.curline = opts_comp.curline or fn.getcmdline()
    opts_comp.curpos = opts_comp.curpos or fn.getcmdpos() - 1
    opts_picker.attach_mappings = function(prompt_bufnr, map)
      local _ = map
      local completed = false
      actions.select_default:replace(function()
        completed = true
        actions.close(prompt_bufnr)
        local selection = action_state.get_selected_entry()
        menu[selection[1]]({}, opts_comp)
      end)
      actions.close:enhance({
        post = function()
          if not completed then
            local left, right = split_curline(opts_comp.curline, opts_comp.curpos)
            complete(left, '', right)
          end
          return true
        end
      })
      return true
    end
    pickers.new({}, opts_picker):find()
  end
end

M.builtin = {}
M.builtin.git_ref = M.create_completer({
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
M.builtin.find_files = M.create_completer({
  picker = require('telescope.builtin').find_files
})
M.builtin.menu = M.create_menu({ menu = M.builtin })

-- set_keymap('c', '<Plug>(test)', function() pcall(insert_ref) end)
set_keymap('c', '<Plug>(test)', M.builtin.find_files)
set_keymap('c', '<C-X><C-R>', function() pcall(M.builtin.git_ref) end)
set_keymap('c', '<C-X><C-F>', function() pcall(M.builtin.find_files) end)
set_keymap('c', '<C-X><C-X>', function() M.builtin.menu() end)
set_keymap('n', '<Space><Space>', ':ab  cd<Left><Left><Left><Plug>(test)')

function M.setup(opt)
  set_keymap('n', plug.colon, ':', { remap = false })
end

return M

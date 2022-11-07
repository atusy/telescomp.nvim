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

local function complete(left, right)
  -- if user want to use own `:`, then map <Plug>(telescomp-colon)
  local cmdline = left .. right
  local cmdpos = fn.strlen(left) + 1
  local setcmdpos = '<C-R><C-R>=setcmdpos(' .. cmdpos .. ')[-1]<CR>'
  feedkeys(
    replace_termcodes([[<C-\><C-N>]] .. plug.colon)
    .. cmdline
    .. replace_termcodes(setcmdpos)
  )
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
      complete(left .. modifier(selection), right)
    end)
    actions.close:enhance({
      post = function()
        if not completed then
          complete(left .. middle, right)
        end
        return true
      end
    })
    return true
  end
end

local function split_curline(arg)
  local curline = arg.curline or fn.getcmdline()
  local curpos = arg.curpos or (fn.getcmdpos() - 1)
  local left = fn.strpart(curline, 0, curpos)
  local middle = ''
  local right = fn.strpart(curline, curpos)
  if arg.expand then
    local matchlist = fn.matchlist(left, [[^\(.* \|\)\([^ ]\+\)$]])
    if #matchlist > 0 then
      left = matchlist[2]
      middle = matchlist[3]
    end
  end
  return left, middle, right
end

function M.spec_completer_options(opts)
  opts = merge({ expand = true }, opts)
  if opts.left == nil then
    opts.left, opts.middle, opts.right = split_curline(opts)
  end
  return opts
end

function M.create_completer(opts)
  local format_selection = opts.format_selection
  local picker = opts.picker
  local opts_picker_default = copy(opts.opts or {})
  local finder = opts_picker_default.finder
  opts_picker_default.finder = type(finder) == 'function' and finders.new_table(finder()) or finder

  return function(opts_picker, opts_comp)
    opts_comp = M.spec_completer_options(opts_comp)

    opts_picker = merge(opts_picker_default, opts_picker)
    opts_picker.default_text = opts_comp.middle
    opts_picker.attach_mappings = insert_selection(
      opts_comp.left, opts_comp.middle, opts_comp.right, format_selection
    )

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
    opts_comp = M.spec_completer_options(opts_comp)

    opts_picker = merge(opts_picker_default, opts_picker)
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
            complete(opts_comp.left, opts_comp.middle, opts_comp.right)
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
set_keymap('c', '<C-X><C-X>', function()
  local opt = M.spec_completer_options({ expand = true })
  local middle = opt.middle
  if string.match(middle, '^%./') ~= nil then
    opt.middle = string.gsub(middle, '^%./', '')
    return M.builtin.find_files({}, opt)
  end
  if string.match(middle, '/') ~= nil then
    return M.builtin.find_files({}, opt)
  end

  return M.builtin.menu({}, opt)
end)

function M.setup(opt)
  set_keymap('n', plug.colon, ':', { remap = false })
end

return M

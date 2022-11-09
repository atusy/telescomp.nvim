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
local conf = require("telescope.config").values

local plug = {
  [":"] = '<Plug>(telescomp-colon)',
  ["/"] = '<Plug>(telescomp-slash)',
  ["?"] = '<Plug>(telescomp-question)',
}

local function set_cmdline(cmdtype, left, right)
  -- if user want to use own `:`, then map <Plug>(telescomp-colon)
  local cmdline = left .. right
  local cmdpos = fn.strlen(left) + 1
  local setcmdpos = '<C-R><C-R>=setcmdpos(' .. cmdpos .. ')[-1]<CR>'
  if not plug[cmdtype] then
    error("telescomp does not support cmdtype " .. cmdtype)
  end
  feedkeys(
    replace_termcodes([[<C-\><C-N>]] .. plug[cmdtype])
    .. cmdline
    .. replace_termcodes(setcmdpos)
  )
end

local function format_default(tbl)
  return table.concat(vim.tbl_map(function(x) return x[1] end, tbl), ' ')
end

local function insert_selection(opts)
  local left = opts.left or ''
  local middle = opts.middle or ''
  local right = opts.right or ''
  local format = opts.formatter or format_default
  return function(prompt_bufnr, map)
    local _ = map
    actions.select_default:replace(function()
      local selections = action_state.get_current_picker(prompt_bufnr):get_multi_selection()
      middle = format(#selections > 1 and selections or { action_state.get_selected_entry() })
      actions.close(prompt_bufnr)
    end)
    actions.close:enhance({
      post = function()
        set_cmdline(opts.cmdtype, left .. middle, right)
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
  if opts.left == nil and opts.middle == nil and opts.right == nil then
    opts.left, opts.middle, opts.right = split_curline(opts)
  else
    opts.left = opts.left or ''
    opts.middle = opts.middle or ''
    opts.right = opts.right or ''
  end
  opts.default_text = opts.default_text or opts.middle
  opts.cmdtype = opts.cmdtype or fn.getcmdtype()
  return opts
end

function M.create_completer(opts)
  local picker = opts.picker
  local opts_picker_default = copy(opts.opts_picker or {})
  local opts_comp_default = opts.opts_completer or {}

  return function(opts_picker, opts_comp)
    opts_comp = M.spec_completer_options(merge(opts_comp_default, opts_comp))

    opts_picker = merge(opts_picker_default, opts_picker)
    opts_picker.default_text = opts_comp.default_text
    opts_picker.attach_mappings = insert_selection(opts_comp)
    if type(opts_picker.finder) == 'function' then
      opts_picker.finder = finders.new_table(opts_picker.finder())
    end

    -- set normal mode
    -- entering telescope ui infers it, but do it manually for sure
    feedkeys(replace_termcodes([[<C-\><C-N>]]))

    if picker then return picker(opts_picker) end

    pickers.new({}, merge({
      sorter = conf.generic_sorter({}),
      prompt_title = 'Complete cmdline',
    }, opts_picker)):find()
  end
end

function M.create_menu(opts)
  local menu = opts.menu
  local menu_keys = {}
  for k, _ in pairs(opts.menu) do
    table.insert(menu_keys, k)
  end

  local opts_picker_default = merge({
    prompt_title = 'Complete cmdline with ...',
    finder = finders.new_table({ results = menu_keys }),
    sorter = conf.generic_sorter({}),
  }, opts.opts)

  return function(opts_picker, opts_comp)
    opts_comp = M.spec_completer_options(opts_comp)

    opts_picker = merge(opts_picker_default, opts_picker)
    opts_picker.attach_mappings = function(prompt_bufnr, _)
      actions.select_default:replace(function()
        actions.close:enhance({ post = function() end })
        actions.close(prompt_bufnr)
        menu[action_state.get_selected_entry()[1]]({}, opts_comp)
      end)
      actions.close:enhance({
        post = function()
          set_cmdline(opts_comp.cmdtype, opts_comp.left .. opts_comp.middle, opts_comp.right)
        end
      })
      return true
    end

    pickers.new({}, opts_picker):find()
  end
end

function M.setup(_)
  set_keymap('n', plug[":"], ':', { remap = false })
  set_keymap('n', plug["/"], '/', { remap = false })
  set_keymap('n', plug["?"], '?', { remap = false })
end

M.setup()

return M

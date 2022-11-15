local fn = vim.fn
local keymap = vim.keymap

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

local plug_cmd = {
  [":"] = '<Plug>(telescomp-colon)',
  ["/"] = '<Plug>(telescomp-slash)',
  ["?"] = '<Plug>(telescomp-question)',
}
local plug_internal = '<Plug>(telescomp-cmd-internal)'

local function complete_cmdline(cmdtype, cmdline, cmdpos)
  if not plug_cmd[cmdtype] then
    error("telescomp does not support cmdtype " .. cmdtype)
  end

  -- one time keymap that sets the cmdline and cmdpos
  keymap.set('c', plug_internal, function()
    -- cmdline can be set directly via feedkeys, but I guess this is more robust
    -- see 836cb415b0d2d954ea781f3178ddeb9e7cfff63a for the implementation with feedkeys
    fn.setcmdline(cmdline)
    keymap.del('c', plug_internal)
    return '<C-R><C-R>=setcmdpos(' .. cmdpos .. ')[-1]<CR>'
  end, { expr = true })

  feedkeys(replace_termcodes(
    [[<C-\><C-N>]] -- ensure normal mode as next plug mapping is defined in normal mode
    .. plug_cmd[cmdtype] -- enter command line of the specific type
    .. plug_internal-- set cmdline and cmdpos
  ))
end

local function format_default(tbl)
  return table.concat(vim.tbl_map(function(x) return x[1] end, tbl), ' ')
end

local function picker_mappings(opts)
  local cmdline = opts.cmdline or ''
  local cmdpos = opts.cmdpos or (fn.strlen(cmdline) + 1)
  return function(prompt_bufnr, map)
    local _ = map
    actions.select_default:replace(function()
      local selections = action_state.get_current_picker(prompt_bufnr):get_multi_selection()
      local left = opts.left .. opts.formatter(
        #selections > 1 and selections or { action_state.get_selected_entry() }
      )
      cmdline = left .. opts.right
      cmdpos = fn.strlen(left) + 1
      actions.close(prompt_bufnr)
    end)
    actions.close:enhance({
      post = function()
        complete_cmdline(opts.cmdtype, cmdline, cmdpos)
      end
    })
    return true
  end
end

local function parse_cmdline(arg)
  local ret = {}
  ret.cmdline = arg.cmdline or fn.getcmdline()
  ret.cmdpos = arg.cmdpos or fn.getcmdpos()
  local pos = ret.cmdpos - 1
  ret.left = fn.strpart(ret.cmdline, 0, pos)
  ret.right = fn.strpart(ret.cmdline, pos)
  ret.default_text = ''

  if arg.expand then
    local matchlist_left = fn.matchlist(ret.left, [[^\(.* \|\)\([^ ]\+\)$]])
    if #matchlist_left > 0 then
      ret.left = matchlist_left[2]
      ret.default_text = matchlist_left[3] .. ret.default_text
    end
    local matchlist_right = fn.matchlist(ret.right, [[^\([^ ]\+\)\( .*\|\)]])
    if #matchlist_right > 0 then
      ret.default_text = ret.default_text .. matchlist_right[2]
      ret.right = matchlist_right[3]
    end
  end

  return ret
end

function M.spec_completer_options(opts)
  opts = merge({ expand = true }, opts)
  if opts.left == nil and opts.right == nil then
    opts = merge(parse_cmdline(opts), opts)
  else
    opts.left = opts.left or ''
    opts.right = opts.right or ''
    opts.default_text = opts.default_text or ''
  end
  opts.cmdtype = opts.cmdtype or fn.getcmdtype()
  opts.formatter = opts.formatter or format_default
  return opts
end

function M.create_completer(args)
  local picker = args.picker
  local opts_picker_default = copy(args.opts_picker or {})
  local opts_comp_user_default = args.opts_completer or {}

  return function(opts_picker, opts_comp)
    opts_comp = M.spec_completer_options(merge(opts_comp_user_default, opts_comp))

    opts_picker = merge(opts_picker_default, opts_picker)
    opts_picker.default_text = opts_comp.default_text or opts_picker.default_text
    opts_picker.attach_mappings = picker_mappings(opts_comp)
    opts_picker.layout_config = opts_picker.layout_config or { anchor = "SW" }
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

function M.create_menu(args)
  local menu = args.menu
  local menu_keys = {}
  for k, _ in pairs(args.menu) do
    table.insert(menu_keys, k)
  end

  local opts_picker_default = merge({
    prompt_title = 'Complete cmdline with ...',
    finder = finders.new_table({ results = menu_keys }),
    sorter = conf.generic_sorter({}),
  }, args.opts)

  return function(opts_picker, opts_comp)
    -- spec completer options except for formatter
    -- a selected picker from the menu may have default formatter
    -- thus, this stage should not fallback to format_default
    local formatter = opts_comp and opts_comp.formatter or nil
    opts_comp = M.spec_completer_options(opts_comp)
    opts_comp.formatter = formatter

    opts_picker = merge(opts_picker_default, opts_picker)
    opts_picker.layout_config = opts_picker.layout_config or { anchor = "SW" }
    opts_picker.attach_mappings = function(prompt_bufnr, _)
      actions.select_default:replace(function()
        actions.close:enhance({ post = function() end })
        actions.close(prompt_bufnr)
        menu[action_state.get_selected_entry()[1]]({}, opts_comp)
      end)
      actions.close:enhance({
        post = function()
          complete_cmdline(opts_comp.cmdtype, opts_comp.cmdline, opts_comp.cmdpos)
        end
      })
      return true
    end

    -- set normal mode
    -- entering telescope ui infers it, but do it manually for sure
    feedkeys(replace_termcodes([[<C-\><C-N>]]))
    pickers.new({}, opts_picker):find()
  end
end

function M.setup(_)
  keymap.set('n', plug_cmd[":"], ':', { remap = false })
  keymap.set('n', plug_cmd["/"], '/', { remap = false })
  keymap.set('n', plug_cmd["?"], '?', { remap = false })
end

M.setup()

return M

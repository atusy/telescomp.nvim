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
  [":"] = '<Plug>(telescomp-colon)',
  ["/"] = '<Plug>(telescomp-slash)',
  ["?"] = '<Plug>(telescomp-question)',
}

local function set_cmdline(cmdtype, left, right)
  -- if user want to use own `:`, then map <Plug>(telescomp-colon)
  local cmdline = left .. right
  local cmdpos = fn.strlen(left) + 1
  local setcmdpos = '<C-R><C-R>=setcmdpos(' .. cmdpos .. ')[-1]<CR>'
  feedkeys(
    replace_termcodes([[<C-\><C-N>]] .. plug[cmdtype])
    .. cmdline
    .. replace_termcodes(setcmdpos)
  )
end

local function insert_selection(opts, formatter)
  local left = opts.left or ''
  local middle = opts.middle or ''
  local right = opts.right or ''
  local format = formatter or function(selection) return selection[1] end
  return function(prompt_bufnr, map)
    local _ = map
    local completed = false
    actions.select_default:replace(function()
      completed = true
      actions.close(prompt_bufnr)
      -- TODO: support multiple selections (cf. https://github.com/nvim-telescope/telescope.nvim/issues/1048#issuecomment-889122232 )
      local selection = action_state.get_selected_entry()
      set_cmdline(opts.cmdtype, left .. format(selection), right)
    end)
    actions.close:enhance({
      post = function()
        if not completed then
          set_cmdline(opts.cmdtype, left .. middle, right)
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
  local formatter_default = opts.formatter
  local picker = opts.picker
  local opts_picker_default = copy(opts.opts or {})
  if type(opts_picker_default.finder) == 'function' then
    opts_picker_default.finder = finders.new_table(opts_picker_default.finder())
  end

  return function(opts_picker, opts_comp, formatter)
    opts_comp = M.spec_completer_options(opts_comp)

    opts_picker = merge(opts_picker_default, opts_picker)
    opts_picker.default_text = opts_comp.default_text
    opts_picker.attach_mappings = insert_selection(opts_comp, formatter or formatter_default)

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
            set_cmdline(opts_comp.left .. opts_comp.middle, opts_comp.right)
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
set_keymap('c', '<C-X><C-R>', M.builtin.git_ref)
set_keymap('c', '<C-X><C-F>', M.builtin.find_files)
set_keymap('c', '<C-X><C-M>', M.builtin.menu)
set_keymap('c', '<C-X><C-K>', M.create_completer({
  opts = {
    finder = function() return { results = { '<Esc>' } } end
  }
}))
set_keymap('c', '<C-X><C-X>', function()
  local opt = M.spec_completer_options({ expand = true })
  local default_text = opt.default_text
  if string.match(default_text, '^%./') ~= nil then
    opt.default_text = string.gsub(default_text, '^%./', '')
    return M.builtin.find_files({}, opt)
  end
  if string.match(default_text, '/') ~= nil then
    return M.builtin.find_files({}, opt)
  end

  return M.builtin.menu({}, opt)
end)

function M.setup(_)
  set_keymap('n', plug[":"], ':', { remap = false })
  set_keymap('n', plug["/"], '/', { remap = false })
  set_keymap('n', plug["?"], '?', { remap = false })
end

return M

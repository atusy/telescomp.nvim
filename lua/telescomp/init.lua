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
  local modes = { "n", "i", "c", "v", "x", "s", "o", "t", "l" }
  vim.keymap.set(modes, lhs.normal, [[<C-\><C-N>]], { remap = false })
  vim.api.nvim_feedkeys(termcodes.normal, "t", true)
  -- vim.schedule(function() vim.keymap.del(modes, lhs.normal) end)
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

function M.create_cmdline_completer(opt)
  return function()
    local curline = vim.fn.getcmdline()
    local curpos = vim.fn.getcmdpos() - 1
    local left = vim.fn.strpart(curline, 0, curpos)
    local right = vim.fn.strpart(curline, curpos)
    set_normal_mode() -- Exit from cmdline happens on entering telescope ui, but do it manually for sure
    pickers.new({}, {
      previewer = opt.previewer or false,
      prompt_title = opt.prompt_title or "Complete cmdline",
      finder = opt.finder and opt.finder() or finders.new_table {
        -- results = vim.fn.split(vim.fn.system([[git for-each-ref --format="%(refname:short)"]]), "\n")
        results = opt.fn_candidates and opt.fn_candidates() or { 'example', '<Esc>' }
      },
      sorter = opt.sorter or conf.generic_sorter({}),
      attach_mappings = function(prompt_bufnr, map)
        local _ = map
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          -- TODO: support multiple selections (cf. https://github.com/nvim-telescope/telescope.nvim/issues/1048#issuecomment-889122232 )
          local selection = action_state.get_selected_entry()
          complete(
            left,
            opt.fn_modify_selection and opt.fn_modify_selection(selection) or selection[1],
            right
          )
        end)
        return true
      end
      -- TODO: fallback to original cmdline when telescope ends without selections
    }):find()
  end
end

M.builtin_cmdline_completer = {}
M.builtin_cmdline_completer.example = M.create_cmdline_completer({})
M.builtin_cmdline_completer.git_ref = M.create_cmdline_completer({
  fn_candidates = function()
    return vim.fn.split(vim.fn.system([[git for-each-ref --format="%(refname:short)"]]), "\n")
  end
})

-- set_keymap('c', '<Plug>(test)', function() pcall(insert_ref) end)
set_keymap('c', '<Plug>(test)', M.builtin_cmdline_completer.example)
set_keymap('c', '<C-X>', function() pcall(M.builtin_cmdline_completer.example) end)
set_keymap('n', '<Space><Space>', ':ab  cd<Left><Left><Left><Plug>(test)')
set_keymap('', '<Space>k', function() vim.pretty_print(vim.api.nvim_get_mode()) end)

function M.setup(opt)
  vim.keymap.set("n", lhs.colon, [[:]], { remap = false })
end

return M

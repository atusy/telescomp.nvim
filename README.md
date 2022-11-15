# Telescomp

Fuzzy completion powered by telescope.nvim

**WARNING: THIS PROJECT IS EXPERIMENTAL**

## Requirements

- Neovim 0.8+
- telescope.nvim

## Recipes

### cmdline

#### Assign keymaps to run completions

**Telescomp** provides variety of pickers from `require('telescomp.cmdline.builtin')`.
Most of them are modified after `require('telescope.builtin')`.
Note that modifications are still work in progress, and some of the pickers may return empty string.

In addition to the modified pickers, there are some original pickers.

- `cmdline` is a picker based on `vim.fn.getcompletion()`.
- `builtin` is a picker of **telescomp**'s builtin pickers like `require('telescope.builtin').builtin`.

##### Example mappings

``` lua
local cmdline_builtin = require('telescomp.cmdline.builtin')

-- complete with `getcompletion`
vim.keymap.set('c', '<C-X><C-X>', telescomp_builtin.cmdline)

-- complete file names powered by telescope.builtin.find_files
vim.keymap.set('c', '<C-X><C-F>', telescomp_builtin.find_files)

-- chose a picker from a list of builtin pickers
vim.keymap.set('c', '<C-X><C-M>', telescomp_builtin.builtin)
```

#### Create your own completions

Use `require('telescomp.cmdline').create_completer`.

This function takes a table, and returns a function.

- `picker`: A picker to be extended (e.g., `require('telescope.builtin').find_files`) or `nil`. `nil` creates a new picker.
- `opts_picker`: Options for picker. Note that `finder` field can be a function that returns a table to be passed to `require('telescope.finders').new_table`. If the value is function, then the field is replaced by its return value before passing to a picker. See example at **Create `find_git_branch`**.
- `opts_comp`: Options for completion. Two of the fields are often used.
    - `expand`: Bool (default: `true`). On completion, *inner Word* on the cursor is used as default text of **Telescope**. Then, the string will be expanded, replaced in other words. If `false`, default text is always blank, and no expansions happen.
    - `formatter`: A function that receives a list of selections. By default, selected items are concatenated with space as a separator.

      ``` lua
      -- default formatter
      function(tbl) return table.concat(vim.tbl_map(function(x) return x[1] end, tbl), ' ') end
      ```

The returned table receives two tables. The first is options of a picker. This is similar to the  just like an argument of Telescope's builtin pickers. The second is option of completion.
- return
    - a function that receives two tables

##### Inherit `find_files` from telescope

and disables its previewer

``` lua
local find_files = require('telescomp.cmdline').create_completer({
  picker = require('telescope.builtin').find_files,
  opts_picker = { previewer = false }
})
vim.keymap.set('c', '<C-X>f', find_files)
```

##### Create `find_git_branch`

``` lua
local git_branch = require('telescomp.cmdline').create_completer({
  opts = {
    finder = function()
      return {
        results = fn.split(fn.system(
          [[git branch --format="%(refname:short)"]]
        ), "\n"),
      }
    end
  }
})
vim.keymap.set('c', '<C-X>b', find_files)
```

#### Create your own menu

instead of `require('telescomp.cmdline.builtin').menu`

``` lua
local my_menu = require('telescope.cmdline').create_menu({
  -- keys as names of items in the menu and values as completion functions
  menu = {
    git_ref = require('telescope.cmdline.builtin').git_ref,
    find_files = require('telescope.cmdline.builtin').find_files,
    git_branch = git_branch,
  },
  -- common options to be passed to a picker
  opts = { previewer = false }
})
```

**telescomp** relies on `nvim_feedkeys()` with no-remap option.
Yet, users can still modify the behavior of some keys like below.

``` lua
vim.keymap.set('n', '<Plug>(telescomp-colon)', ':', { remap = true })
```

#### Conditional completions

Call `find_file` if `default_text` contains "/" and call `menu` otherwise.

``` lua
vim.keymap.set('c', '<C-X><C-X>', function()
  local cmdline_builtin = require('telescomp.cmdline.builtin')

  local opt = require('telescomp.cmdline').spec_completer_options({ expand = true })
  local default_text = opt.default_text
  if string.match(default_text, '/') ~= nil then
    return cmdline_builtin.find_files({}, opt)
  end

  return cmdline_builtin.menu({}, opt)
end)
```

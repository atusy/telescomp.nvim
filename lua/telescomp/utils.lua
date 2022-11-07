local api = vim.api
local M = {}

function M.copy(x)
  local ret = {}
  for k, v in pairs(x) do
    ret[k] = v
  end
  return ret
end

function M.merge(x, y)
  local ret = x and M.copy(x) or {}
  for k, v in pairs(y or {}) do
    ret[k] = v
  end
  return ret
end

function M.replace_termcodes(x)
  return api.nvim_replace_termcodes(x, true, false, true)
end

function M.feedkeys(x)
  api.nvim_feedkeys(x, 'n', false)
end

return M

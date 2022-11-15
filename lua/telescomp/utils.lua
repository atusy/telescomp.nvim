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

function M.callable(x)
  if type(x) == 'function' then
    return true
  end
  if type(x) == 'table' then
    local meta = debug.getmetatable(x)
    return type(meta) == 'table' and type(meta.__call) == 'function'
  end
  return false
end

function M.warn(msg)
  vim.notify(msg, vim.log.levels.WARN)
end

return M

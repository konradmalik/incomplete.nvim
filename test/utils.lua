local M = {}

---@param bufnr integer
---@return string[]
function M.get_buf_lines(bufnr) return vim.api.nvim_buf_get_lines(bufnr, 0, -1, true) end

---@param winid integer
---@param bufnr integer
---@param body string|string[]
---@return vim.v.completed_item
function M.simulate_complete_done(winid, bufnr, body)
    local completed_item = { word = "word", user_data = { incomplete = { body = body } } }
    -- fake as if we used completion menu (word would be inserted)
    vim.api.nvim_buf_set_lines(bufnr, 0, 1, true, { completed_item.word .. " " })
    vim.api.nvim_win_set_cursor(winid, { 1, #completed_item.word })
    return completed_item
end

return M

local group = vim.api.nvim_create_augroup("incomplete", { clear = true })
vim.api.nvim_create_autocmd("CompleteDone", {
    group = group,
    callback = function()
        require("incomplete")._handle_autocmd(vim.v.completed_item, vim.v.event["reason"])
    end,
})

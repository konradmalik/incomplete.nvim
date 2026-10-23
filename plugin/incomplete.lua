local group = vim.api.nvim_create_augroup("incomplete", { clear = true })
vim.api.nvim_create_autocmd("CompleteDone", {
    group = group,
    callback = function()
        require("incomplete")._handle_autocmd(vim.v.completed_item, vim.v.event["reason"])
    end,
})

vim.api.nvim_create_user_command(
    "IncompleteReload",
    function() require("incomplete").reload() end,
    { desc = "Reload snippets from the runtimepath" }
)

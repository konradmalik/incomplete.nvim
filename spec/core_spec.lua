local inc = require("incomplete")
local original_rtp = vim.o.rtp

describe("in incomplete module", function()
    setup(function() vim.o.rtp = "./test," .. vim.o.rtp end)
    teardown(function() vim.o.rtp = original_rtp end)

    it("compfunc returns proper items for unknown type", function()
        -- arrange
        local bufnr = vim.api.nvim_create_buf(true, false)
        vim.bo[bufnr].filetype = "something"
        vim.api.nvim_set_current_buf(bufnr)

        -- act
        local actual_snippets = inc.completefunc(0, "")

        -- assert
        assert.are.same(2, #actual_snippets.words)
    end)

    it("compfunc returns proper items for known type", function()
        -- arrange
        local bufnr = vim.api.nvim_create_buf(true, false)
        vim.bo[bufnr].filetype = "go"
        vim.api.nvim_set_current_buf(bufnr)

        -- act
        local actual_snippets = inc.completefunc(0, "")

        -- assert
        assert.are.same(3, #actual_snippets.words)
    end)

    it("compfunc has caching", function()
        -- arrange
        local bufnr = vim.api.nvim_create_buf(true, false)
        vim.bo[bufnr].filetype = "go"
        vim.api.nvim_set_current_buf(bufnr)
        vim.o.rtp = original_rtp

        -- act
        local actual_snippets = inc.completefunc(0, "")

        -- assert
        assert.are.same(3, #actual_snippets.words)
    end)
end)

local inc = require("incomplete")
local utils = require("test.utils")
local original_rtp = vim.o.rtp

---@return integer
local function get_window(bufnr)
    local winid = vim.api.nvim_open_win(bufnr, true, { split = "right" })
    finally(function() vim.api.nvim_win_close(winid, true) end)
    return winid
end

describe("in incomplete module", function()
    local bufnr
    before_each(function()
        vim.o.rtp = "./test," .. vim.o.rtp

        bufnr = vim.api.nvim_create_buf(true, false)
        vim.bo[bufnr].filetype = "go"
        vim.api.nvim_set_current_buf(bufnr)
    end)
    after_each(function()
        vim.o.rtp = original_rtp
        vim.api.nvim_buf_delete(bufnr, { force = true })
    end)

    it("compfunc returns proper items for unknown type", function()
        -- arrange
        vim.bo[bufnr].filetype = "something"

        -- act
        local actual_snippets = inc.completefunc(0, "")

        -- assert
        assert.are.same(3, #actual_snippets.words)
    end)

    it("compfunc returns proper items for known type", function()
        -- act
        local actual_snippets = inc.completefunc(0, "")

        -- assert
        assert.are.same(5, #actual_snippets.words)
    end)

    it("compfunc has caching", function()
        -- arrange
        vim.o.rtp = original_rtp

        -- act
        local actual_snippets = inc.completefunc(0, "")

        -- assert
        assert.are.same(5, #actual_snippets.words)
    end)

    it("_handle_autocmd works for 'accepted'", function()
        -- arrange
        local winid = get_window(bufnr)
        local completed_item = utils.simulate_complete_done(winid, bufnr, "body")

        -- act
        inc._handle_autocmd(completed_item, "accept")

        -- assert
        local expected_lines = { "body " }
        local actual_lines = utils.get_buf_lines(bufnr)
        assert.are.same(expected_lines, actual_lines)
    end)

    it("_handle_autocmd does nothing for other reasons", function()
        -- arrange
        local winid = get_window(bufnr)
        local completed_item = utils.simulate_complete_done(winid, bufnr, "body")

        -- act
        inc._handle_autocmd(completed_item, "other")

        -- assert
        local expected_lines = { "word " }
        local actual_lines = utils.get_buf_lines(bufnr)
        assert.are.same(expected_lines, actual_lines)
    end)

    it("_handle_autocmd works for multi-line bodies", function()
        -- arrange
        local winid = get_window(bufnr)
        local completed_item = utils.simulate_complete_done(
            winid,
            bufnr,
            { "body line 1", "body line 2", "body line 3" }
        )

        -- act
        inc._handle_autocmd(completed_item, "accept")

        -- assert
        -- totally no idea why there are spaces in line 2 and 3...
        -- but this is the result of vim.snippet.expand.
        -- Can it be because of insert mode problems in nlua?
        local expected_lines = { "body line 1", " body line 2", " body line 3 " }
        local actual_lines = utils.get_buf_lines(bufnr)
        assert.are.same(expected_lines, actual_lines)
    end)
end)

---@class CompleteItem
---@field word string actual completion value
---@field menu string menu entry label
---@field abbr? string menu entry
---@field info? string additional info displayed next to menu entry
---@field user_data {source: {incomplete: true}}

---@class CompleteDict
---@field words string|CompleteItem
---@field refresh? "always"|nil

--- needed for friendly-snippets
--- if something's not here, the original ft will be used
local additional_loads = {
    cs = { "csharp" },
}

---@param what string
---@return CompleteItem[]
local function build_cache_for(what) return require("incomplete.json").load_for(what) end

---@param completed_item {word: string}
local function handle_accepted_snippet(completed_item)
    local word = completed_item.word ---@type string
    local body = vim.tbl_get(completed_item, "user_data", "incomplete", "body")
    -- no cached snippet like that
    if not body then
        vim.notify("no snippet body for: '" .. word .. "'", vim.log.levels.ERROR)
        return
    end

    local cursor = vim.api.nvim_win_get_cursor(vim.api.nvim_get_current_win())
    local row, col = cursor[1] - 1, cursor[2]
    -- need to remove just inserted, unexpanded word
    vim.api.nvim_buf_set_text(vim.api.nvim_get_current_buf(), row, col - #word, row, col, {})
    if type(body) == "table" then body = table.concat(body, "\n") end
    -- this adds the text directly
    vim.snippet.expand(body)
end

---@param completed_item {user_data: table?}
local function is_relevant_event(completed_item)
    return vim.tbl_get(completed_item, "user_data", "incomplete") ~= nil
end

---@param completed_item CompleteItem
---@param event_reason string
local function handle_autocmd(completed_item, event_reason)
    if not is_relevant_event(completed_item) then return end

    if event_reason == "accept" then handle_accepted_snippet(completed_item) end
end

local M = {}

M._handle_autocmd = handle_autocmd

function M.setup()
    local group = vim.api.nvim_create_augroup("incomplete", { clear = true })
    vim.api.nvim_create_autocmd("CompleteDone", {
        group = group,
        callback = function() handle_autocmd(vim.v.completed_item, vim.v.event["reason"]) end,
    })

    vim.o.completefunc = "v:lua.require'incomplete'.completefunc"
end

do
    ---@type table<string,CompleteItem[]>
    local cached_snippets = {}

    ---uses or populates cache and injects data into target
    ---this mutates gathered_snippets
    ---@param what string
    ---@param target table[] will be mutated
    local function inject_snippets_for(what, target)
        if not cached_snippets[what] then cached_snippets[what] = build_cache_for(what) end
        vim.list_extend(target, cached_snippets[what])
    end

    ---completefunc implementation that serves snippets
    ---@param findstart integer
    ---@param base string
    ---@return integer|{words: CompleteItem[]}
    function M.completefunc(findstart, base)
        if findstart == 1 and base == "" then
            -- column where completion starts
            -- eg. return 0 for start of the line
            -- return -1 for cursor column
            return -1
        end

        local bufnr = vim.api.nvim_get_current_buf()
        local orig_ft = vim.bo[bufnr].filetype
        local all_ft = additional_loads[orig_ft] or {}
        table.insert(all_ft, orig_ft)

        local gathered_snippets = {}

        for _, ft in ipairs(all_ft) do
            if ft ~= "" then inject_snippets_for(ft, gathered_snippets) end
        end

        inject_snippets_for("all", gathered_snippets)

        return {
            ---@type CompleteItem[]
            words = gathered_snippets,
        }
    end
end

return M

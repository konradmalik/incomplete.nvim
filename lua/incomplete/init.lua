---@class CompleteDict
---@field words string[]|vim.v.completed_item[]
---@field refresh? "always"|nil

---@param what string
---@return vim.v.completed_item[]
local function build_cache_for(what) return require("incomplete.json").load_for(what) end

---@param completed_item {word: string, user_data: table}
local function handle_accepted_snippet(completed_item)
    local word = completed_item.word ---@type string
    -- always present, snippets without a body are skipped when loading
    local body = vim.tbl_get(completed_item, "user_data", "incomplete", "body")

    local cursor = vim.api.nvim_win_get_cursor(vim.api.nvim_get_current_win())
    local row, col = cursor[1] - 1, cursor[2]
    -- the just inserted word must be right before the cursor ('infercase' may change its case)
    local inserted = vim.api.nvim_get_current_line():sub(col - #word + 1, col)
    if col < #word or inserted:lower() ~= word:lower() then
        vim.notify("cannot find inserted snippet prefix: '" .. word .. "'", vim.log.levels.ERROR)
        return
    end
    -- need to remove just inserted, unexpanded word
    vim.api.nvim_buf_set_text(vim.api.nvim_get_current_buf(), row, col - #word, row, col, {})
    if type(body) == "table" then body = table.concat(body, "\n") end
    -- this adds the text directly
    vim.snippet.expand(body)
end

---@param completed_item {user_data: table?}
---@return boolean
local function is_relevant_event(completed_item)
    return vim.tbl_get(completed_item, "user_data", "incomplete") ~= nil
end

---@param items vim.v.completed_item[]
---@param base string
---@return vim.v.completed_item[]
local function filter(items, base)
    if base == "" then return items end
    if vim.o.completeopt:find("fuzzy", 1, true) then
        return vim.fn.matchfuzzy(items, base, { key = "word" })
    end
    return vim.tbl_filter(function(item) return vim.startswith(item.word, base) end, items)
end

---@param items vim.v.completed_item[]
---@param base string
---@return boolean
local function any_starts_with(items, base)
    for _, item in ipairs(items) do
        if vim.startswith(item.word, base) then return true end
    end
    return false
end

local M = {}

---@param completed_item vim.v.completed_item
---@param event_reason string
M._handle_autocmd = function(completed_item, event_reason)
    if not is_relevant_event(completed_item) then return end

    if event_reason == "accept" then handle_accepted_snippet(completed_item) end
end

do
    ---@type table<string,vim.v.completed_item[]>
    local cached_snippets = {}

    ---uses or populates cache and injects data into target
    ---this mutates gathered_snippets
    ---@param what string
    ---@param target table[] will be mutated
    local function inject_snippets_for(what, target)
        if not cached_snippets[what] then cached_snippets[what] = build_cache_for(what) end
        vim.list_extend(target, cached_snippets[what])
    end

    ---@type table<string,string[]>
    local ft_extensions = {}

    ---Clears all cached snippets, they will be loaded again from the runtimepath when needed.
    ---Useful after adding/editing snippet files or loading a plugin that provides snippets.
    function M.reload()
        cached_snippets = {}
        require("incomplete.json").reset()
    end

    ---Allows loading snippets from other filetypes in addition to the original one.
    ---NOTE: multiple calls for the same original will keep overwriting the entry.
    ---@param original_ft string
    ---@param additional_fts string[]
    function M.extend_filetype(original_ft, additional_fts)
        ft_extensions[original_ft] = additional_fts
    end

    ---Filetypes to load snippets for, without duplicates.
    ---Compound filetypes (eg. "javascript.jsx") are split into their parts.
    ---@param ft string
    ---@return string[]
    local function filetypes_for(ft)
        local result, seen = {}, {}
        local function add(f)
            if f ~= "" and not seen[f] then
                seen[f] = true
                table.insert(result, f)
            end
        end

        local parts = { ft }
        if ft:find(".", 1, true) then
            vim.list_extend(parts, vim.split(ft, ".", { plain = true }))
        end
        for _, part in ipairs(parts) do
            add(part)
            for _, ext in ipairs(ft_extensions[part] or {}) do
                add(ext)
            end
        end
        add("all")
        return result
    end

    ---@param bufnr integer
    ---@return vim.v.completed_item[]
    local function gather_snippets(bufnr)
        ---@type vim.v.completed_item[]
        local gathered_snippets = {}
        for _, ft in ipairs(filetypes_for(vim.bo[bufnr].filetype)) do
            inject_snippets_for(ft, gathered_snippets)
        end
        return gathered_snippets
    end

    ---completefunc implementation that serves snippets
    ---@param findstart integer 1 on first call, 0 on further calls
    ---@param base string ignore when findstart == 1, use as filter later
    ---@return integer|CompleteDict column to start completion when findstart == 1, return completions otherwise
    function M.completefunc(findstart, base)
        local bufnr = vim.api.nvim_get_current_buf()

        if findstart == 1 then
            -- 0-indexed byte column where completion starts.
            -- Prefer all non-blank text before the cursor (snippet prefixes may contain non-keyword chars),
            -- fall back to keyword chars only (eg. "foo(sh" should complete "sh").
            local col = vim.api.nvim_win_get_cursor(0)[2]
            local line = vim.api.nvim_get_current_line():sub(1, col)
            local nonblank_start = line:find("%S*$") - 1
            if any_starts_with(gather_snippets(bufnr), line:sub(nonblank_start + 1)) then
                return nonblank_start
            end
            return vim.fn.match(line, [[\k*$]])
        end

        ---@type CompleteDict
        return {
            words = filter(gather_snippets(bufnr), base),
        }
    end
end

return M

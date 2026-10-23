local json = require("incomplete.json")

local M = {}

---filetype to its snippets
---@type table<string,vim.v.completed_item[]>
local cache = {}

---filetype to additional filetypes to load snippets from
---@type table<string,string[]>
local ft_extensions = {}

---@param ft string
---@return vim.v.completed_item[]
local function snippets_for(ft)
    cache[ft] = cache[ft] or json.load_for(ft)
    return cache[ft]
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

    for _, part in ipairs(vim.list_extend({ ft }, vim.split(ft, ".", { plain = true }))) do
        add(part)
        for _, ext in ipairs(ft_extensions[part] or {}) do
            add(ext)
        end
    end
    add("all")
    return result
end

---@return vim.v.completed_item[]
local function current_snippets()
    local items = {}
    for _, ft in ipairs(filetypes_for(vim.bo.filetype)) do
        vim.list_extend(items, snippets_for(ft))
    end
    return items
end

---0-indexed byte column where completion starts.
---Prefers all non-blank text before the cursor (snippet prefixes may contain non-keyword chars),
---falls back to keyword chars only (eg. "foo(sh" should complete "sh").
---@param items vim.v.completed_item[]
---@return integer
local function find_start(items)
    local col = vim.api.nvim_win_get_cursor(0)[2]
    local line = vim.api.nvim_get_current_line():sub(1, col)
    local start = line:find("%S*$") - 1
    local typed = line:sub(start + 1)
    if vim.iter(items):any(function(item) return vim.startswith(item.word, typed) end) then
        return start
    end
    return vim.fn.match(line, [[\k*$]])
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

---Replaces the just inserted word with the expanded snippet
---@param word string
---@param body string|string[]
local function expand(word, body)
    local row, col = unpack(vim.api.nvim_win_get_cursor(0))
    local inserted = vim.api.nvim_get_current_line():sub(col - #word + 1, col)
    -- compare ignoring case, 'infercase' may change it
    if col < #word or inserted:lower() ~= word:lower() then
        vim.notify(
            "incomplete: cannot find inserted snippet prefix '" .. word .. "'",
            vim.log.levels.ERROR
        )
        return
    end
    vim.api.nvim_buf_set_text(0, row - 1, col - #word, row - 1, col, {})
    if type(body) == "table" then body = table.concat(body, "\n") end
    vim.snippet.expand(body)
end

---@param completed_item vim.v.completed_item
---@param event_reason string
function M._handle_autocmd(completed_item, event_reason)
    local body = vim.tbl_get(completed_item, "user_data", "incomplete", "body")
    if event_reason == "accept" and body then expand(completed_item.word, body) end
end

---Clears all cached snippets, they will be loaded again from the runtimepath when needed.
---Useful after adding/editing snippet files or loading a plugin that provides snippets.
function M.reload()
    cache = {}
    json.reset()
end

---Allows loading snippets from other filetypes in addition to the original one.
---NOTE: multiple calls for the same original will keep overwriting the entry.
---@param original_ft string
---@param additional_fts string[]
function M.extend_filetype(original_ft, additional_fts) ft_extensions[original_ft] = additional_fts end

---completefunc implementation that serves snippets
---@param findstart integer 1 on first call, 0 on further calls
---@param base string ignore when findstart == 1, use as filter later
---@return integer|{words: vim.v.completed_item[]} column to start completion when findstart == 1, completions otherwise
function M.completefunc(findstart, base)
    if findstart == 1 then return find_start(current_snippets()) end
    return { words = filter(current_snippets(), base) }
end

return M

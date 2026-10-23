---@param file string
---@return table
local function read_json(file)
    -- vscode snippet files are often jsonc
    local decoded = vim.json.decode(vim.fn.readblob(file), { skip_comments = true })
    assert(type(decoded) == "table", "expected a json object")
    return decoded
end

---Runs fn, on error notifies and returns nil, so that one broken file does not break the rest
---@generic T
---@param fn fun(): T
---@param file string reported on error
---@return T?
local function try(fn, file)
    local ok, result = pcall(fn)
    if ok then return result end
    vim.notify(("incomplete: skipping '%s': %s"):format(file, result), vim.log.levels.WARN)
end

---Builds a ft to snippet absolute paths lookup table from vscode-like package.json files
---@return table<string,string[]>
local function build_lookup()
    local lookup = {}
    for _, pattern in ipairs({ "package.json", "snippets/package.json" }) do
        for _, pkgfile in ipairs(vim.api.nvim_get_runtime_file(pattern, true)) do
            try(function()
                local dir = vim.fs.dirname(pkgfile)
                for _, entry in
                    ipairs(vim.tbl_get(read_json(pkgfile), "contributes", "snippets") or {})
                do
                    local languages = entry.language
                    if type(languages) == "string" then languages = { languages } end
                    if type(entry.path) == "string" then
                        -- absolute, so that it does not depend on cwd when loaded later
                        local path =
                            vim.fs.normalize(vim.fs.abspath(vim.fs.joinpath(dir, entry.path)))
                        for _, lang in ipairs(languages or {}) do
                            lookup[lang] = lookup[lang] or {}
                            table.insert(lookup[lang], path)
                        end
                    end
                end
            end, pkgfile)
        end
    end
    return lookup
end

---Converts a vscode-like snippets file into completion items.
---Snippets with multiple prefixes produce one item per prefix, snippets without a body are skipped.
---@param file string
---@return vim.v.completed_item[]
local function load_file(file)
    local menu = vim.tbl_get(vim.g, "incomplete", "menu") or "󰩫"
    local items = {}
    for name, snippet in pairs(read_json(file)) do
        local body = type(snippet) == "table" and snippet.body
        if type(body) == "table" then body = table.concat(body, "\n") end

        if type(body) == "string" then
            local info = body
            if type(snippet.description) == "string" and snippet.description ~= "" then
                info = snippet.description .. "\n\n" .. body
            end

            local prefixes = snippet.prefix
            if type(prefixes) ~= "table" then prefixes = { prefixes } end
            if #prefixes == 0 then prefixes = { name } end

            for _, prefix in ipairs(prefixes) do
                if type(prefix) == "string" and prefix ~= "" then
                    ---@type vim.v.completed_item
                    local item = {
                        word = prefix,
                        menu = menu,
                        info = info,
                        user_data = { incomplete = body },
                    }
                    table.insert(items, item)
                end
            end
        end
    end
    return items
end

local M = {}

---@type table<string,string[]>?
local lookup = nil

---Reads snippets for a filetype from json files specified in package.json files on the runtimepath.
---Each file is converted separately, so snippets with the same name in different files are all kept.
---@param ft string filetype or "all" for non-filetype specific
---@return vim.v.completed_item[]
function M.load_for(ft)
    lookup = lookup or build_lookup()

    local items = {}
    for _, file in ipairs(lookup[ft] or {}) do
        vim.list_extend(items, try(function() return load_file(file) end, file) or {})
    end
    return items
end

---Forgets the ft to snippet files lookup, it will be rebuilt from the runtimepath on next load.
function M.reset() lookup = nil end

return M

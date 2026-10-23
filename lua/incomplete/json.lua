-- vscode snippet files are often jsonc
local json_opts = vim.fn.has("nvim-0.12") == 1 and { skip_comments = true } or nil

---Reads and decodes a single json file, notifies and returns nil on failure
---@param file string
---@return table?
local function read_json(file)
    local ok, result = pcall(function()
        local lines = vim.fn.readfile(file)
        return vim.json.decode(table.concat(lines, "\n"), json_opts)
    end)
    if not ok then
        vim.notify(
            "incomplete: cannot read '" .. file .. "': " .. tostring(result),
            vim.log.levels.WARN
        )
        return nil
    end
    if type(result) ~= "table" then
        vim.notify("incomplete: expected a json object in '" .. file .. "'", vim.log.levels.WARN)
        return nil
    end
    return result
end

---@class JsonSnippet
---@field prefix? string|string[]
---@field description? string
---@field body string|string[]

---@param snippet JsonSnippet
---@return string
local function build_info(snippet)
    local body = type(snippet.body) == "table" and table.concat(snippet.body, "\n") or snippet.body
    if type(snippet.description) ~= "string" or snippet.description == "" then return body end
    return snippet.description .. "\n\n" .. body
end

---converts json snippets into incomplete.
---Snippets with multiple prefixes produce one item per prefix, snippets without a body are skipped.
---@param snips table<string, JsonSnippet>
---@return vim.v.completed_item[]
local function convert(snips)
    local menu = vim.tbl_get(vim.g, "incomplete", "menu") or "󰩫"
    local items = {}
    for key, value in pairs(snips) do
        if
            type(value) == "table" and (type(value.body) == "string" or type(value.body) == "table")
        then
            local prefixes = value.prefix
            if type(prefixes) ~= "table" then prefixes = { prefixes } end
            if #prefixes == 0 then prefixes = { key } end
            local info = build_info(value)
            for _, prefix in ipairs(prefixes) do
                -- skips eg. numeric keys of json arrays
                if type(prefix) == "string" and prefix ~= "" then
                    ---@type vim.v.completed_item
                    local item = {
                        word = prefix,
                        menu = menu,
                        info = info,
                        user_data = { incomplete = value },
                    }
                    table.insert(items, item)
                end
            end
        end
    end
    return items
end

--- Builds a ft to snippet absolute paths lookup table
---@return table<string,string[]>
local function build_ft_snippet_lookup()
    ---filetype to paths
    ---@type table<string,string[]>
    local lookup = {}

    for _, pattern in ipairs({ "package.json", "snippets/package.json" }) do
        for _, pkgfile in ipairs(vim.api.nvim_get_runtime_file(pattern, true)) do
            local packagedir = vim.fs.dirname(pkgfile)
            local pkg = read_json(pkgfile) or {}
            local snippets = vim.tbl_get(pkg, "contributes", "snippets") or {}

            for _, snippet_entry in ipairs(snippets) do
                local languages = snippet_entry["language"]
                if type(languages) == "string" then languages = { languages } end
                local relative_path = snippet_entry["path"]

                if type(languages) == "table" and type(relative_path) == "string" then
                    local absolute_path = vim.fs.abspath(vim.fs.joinpath(packagedir, relative_path))
                    for _, lang in ipairs(languages) do
                        if not lookup[lang] then lookup[lang] = {} end
                        table.insert(lookup[lang], absolute_path)
                    end
                end
            end
        end
    end
    return lookup
end

local M = {}

do
    local lookup = nil

    ---Reads snippets from json files specified in package.json.
    ---Each file is converted separately, so snippets with the same name in different files are all kept.
    ---@param ft string filetype or "all" for non-filetype specific
    ---@return vim.v.completed_item[]
    function M.load_for(ft)
        if not lookup then lookup = build_ft_snippet_lookup() end

        local items = {}
        for _, file in ipairs(lookup[ft] or {}) do
            local snips = read_json(file)
            local ok, converted = pcall(convert, snips or {})
            if ok then
                vim.list_extend(items, converted)
            else
                vim.notify(
                    "incomplete: cannot convert '" .. file .. "': " .. tostring(converted),
                    vim.log.levels.WARN
                )
            end
        end
        return items
    end

    ---Forgets the ft to snippet files lookup, it will be rebuilt from the runtimepath on next load.
    function M.reset() lookup = nil end
end

return M

---Reads and decodes a single json file, notifies and returns nil on failure
---@param file string
---@return table?
local function read_json(file)
    local ok, result = pcall(function()
        local lines = vim.fn.readfile(file)
        return vim.json.decode(table.concat(lines, ""))
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

---get longest string from a table
---@param list string[]
---@return string?
local function longest_string(list)
    local longest = list[1]
    for _, v in ipairs(list) do
        if #v > #longest then longest = v end
    end
    return longest
end

---get prefix
---@param prefix string[]|string
---@return string
local function get_prefix(prefix)
    if type(prefix) == "string" then return prefix end

    return longest_string(prefix) or prefix[1]
end

---@class JsonSnippet
---@field prefix? string
---@field description string
---@field body string|string[]

---converts json snippets into incomplete
---@param snips table<string, JsonSnippet>
---@return vim.v.completed_item[]
local function convert(snips)
    return vim.iter(snips)
        :filter(function(_, value) return type(value) == "table" end)
        :map(
            ---@param key string
            ---@param value JsonSnippet
            ---@return vim.v.completed_item
            function(key, value)
                ---@type vim.v.completed_item
                return {
                    word = value.prefix and get_prefix(value.prefix) or key,
                    menu = "󰩫",
                    info = value.description,
                    user_data = { incomplete = value },
                }
            end
        )
        :totable()
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
            if snips then vim.list_extend(items, convert(snips)) end
        end
        return items
    end
end

return M

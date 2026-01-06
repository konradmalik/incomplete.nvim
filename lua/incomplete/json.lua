---Reads all provided files and merges results
---@param files string[]
---@return table
local function deep_read(files)
    return vim.iter(files)
        :map(function(file)
            local lines = vim.fn.readfile(file)
            local str = table.concat(lines, "")
            return vim.json.decode(str)
        end)
        :fold({}, function(acc, v) return vim.tbl_deep_extend("force", acc, v) end)
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

---converts json snippets into incomplete
---@param snips table<string, table>[]
---@return vim.v.completed_item[]
local function convert(snips)
    return vim.tbl_values(vim.tbl_map(function(value)
        ---@type vim.v.completed_item
        return {
            word = get_prefix(value.prefix),
            menu = "󰩫",
            info = value.description,
            user_data = { incomplete = value },
        }
    end, snips))
end

--- Builds a ft to snippet absolute paths lookup table
---@return table<string,string[]>
local function build_ft_snippet_lookup()
    ---filetype to paths
    ---@type table<string,string[]>
    local lookup = {}

    for _, pkgfile in ipairs(vim.api.nvim_get_runtime_file("snippets/package.json", true)) do
        local packagedir = vim.fs.dirname(pkgfile)
        local pkg = deep_read({ pkgfile })
        local snippets = vim.tbl_get(pkg, "contributes", "snippets") or {}

        for _, snippet_entry in ipairs(snippets) do
            local languages = {}
            if type(snippet_entry["language"]) == "string" then
                languages = { snippet_entry["language"] }
            else
                languages = snippet_entry["language"]
            end

            for _, lang in ipairs(languages) do
                if not lookup[lang] then lookup[lang] = {} end
                local relative_path = snippet_entry["path"]
                local absolute_path = vim.fs.abspath(vim.fs.joinpath(packagedir, relative_path))
                table.insert(lookup[lang], absolute_path)
            end
        end
    end
    return lookup
end

local M = {}

do
    local lookup = nil

    ---Reads snippets from json files specified in package.json
    ---@param ft string filetype or "all" for non-filetype specific
    ---@return table[]
    function M.load_for(ft)
        if not lookup then lookup = build_ft_snippet_lookup() end

        local snips = deep_read(lookup[ft] or {})
        return convert(snips)
    end
end

return M

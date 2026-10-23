local json = require("incomplete.json")
local original_rtp = vim.o.rtp

describe("json module", function()
    setup(function() vim.o.rtp = "./test," .. vim.o.rtp end)
    teardown(function() vim.o.rtp = original_rtp end)

    it("reads snippets for 'all'", function()
        -- act
        local actual_snippets = json.load_for("all")

        -- assert
        table.sort(actual_snippets, function(a, b) return a.word < b.word end)
        assert.are.same({
            {
                ["info"] = "when you have enough\n\n(╯°□°)╯彡┻━┻",
                ["menu"] = "󰩫",
                ["user_data"] = {
                    ["incomplete"] = "(╯°□°)╯彡┻━┻",
                },
                ["word"] = "rageflip",
            },
            {
                ["info"] = "when you have nothing better to say\n\n¯\\_(ツ)_/¯",
                ["menu"] = "󰩫",
                ["user_data"] = {
                    ["incomplete"] = "¯\\_(ツ)_/¯",
                },
                ["word"] = "shrug",
            },
            {
                ["info"] = "iksde\n\nxD",
                ["menu"] = "󰩫",
                ["user_data"] = {
                    ["incomplete"] = "xD",
                },
                ["word"] = "xd",
            },
        }, actual_snippets)
    end)

    it("reads snippets for an ft when two are specified, one item per prefix", function()
        -- act
        local actual_snippets = json.load_for("go")

        -- assert
        table.sort(actual_snippets, function(a, b) return a.info .. a.word < b.info .. b.word end)
        local single = {
            ["body"] = "(|-.-|)",
            ["prefix"] = { "go", "gopher" },
            ["description"] = "ChatGPT's suggested single line gopher ascii art...",
        }
        local doubled = {
            ["body"] = "(|-.-|)(|-.-|)",
            ["prefix"] = { "go", "gopher" },
            ["description"] = "ChatGPT's suggested single line gopher ascii art... but doubled",
        }
        local single_info = single.description .. "\n\n" .. single.body
        local doubled_info = doubled.description .. "\n\n" .. doubled.body
        assert.are.same({
            {
                info = single_info,
                menu = "󰩫",
                user_data = { incomplete = single.body },
                word = "go",
            },
            {
                info = single_info,
                menu = "󰩫",
                user_data = { incomplete = single.body },
                word = "gopher",
            },
            {
                info = doubled_info,
                menu = "󰩫",
                user_data = { incomplete = doubled.body },
                word = "go",
            },
            {
                info = doubled_info,
                menu = "󰩫",
                user_data = { incomplete = doubled.body },
                word = "gopher",
            },
        }, actual_snippets)
    end)

    it("reads snippets even when prefix is missing", function()
        -- act
        local actual_snippets = json.load_for("org")

        -- assert
        table.sort(actual_snippets, function(a, b) return a.info < b.info end)
        assert.are.same({
            {
                ["info"] = "#+attr_html: :width ...\n\n#+ATTR_HTML: :width ${1:500px}",
                ["menu"] = "󰩫",
                ["user_data"] = {
                    ["incomplete"] = "#+ATTR_HTML: :width ${1:500px}",
                },
                ["word"] = "html width",
            },
            {
                ["info"] = "TODO item\n\nTODO ${1:task description}",
                ["menu"] = "󰩫",
                ["user_data"] = {
                    ["incomplete"] = "TODO ${1:task description}",
                },
                ["word"] = "todo",
            },
        }, actual_snippets)
    end)

    it("uses menu from vim.g.incomplete", function()
        -- arrange
        vim.g.incomplete = { menu = "[S]" }
        finally(function() vim.g.incomplete = nil end)

        -- act
        local actual_snippets = json.load_for("all")

        -- assert
        assert.are.same(
            { "[S]" },
            vim.fn.uniq(vim.tbl_map(function(i) return i.menu end, actual_snippets))
        )
    end)

    it("reset rebuilds the lookup from the current runtimepath", function()
        -- arrange
        json.load_for("all")
        finally(function()
            vim.o.rtp = "./test," .. original_rtp
            json.reset()
        end)
        vim.o.rtp = original_rtp

        -- act
        json.reset()
        local actual_snippets = json.load_for("all")

        -- assert
        assert.are.same({}, actual_snippets)
    end)
end)

describe("json module edge cases", function()
    local json_edge
    local notifications
    local notify = vim.notify

    setup(function()
        vim.o.rtp = "./test/edge," .. original_rtp
        -- fresh module so that the lookup is built with this rtp
        package.loaded["incomplete.json"] = nil
        json_edge = require("incomplete.json")
    end)
    teardown(function()
        vim.o.rtp = original_rtp
        package.loaded["incomplete.json"] = nil
    end)
    before_each(function()
        notifications = {}
        vim.notify = function(msg) table.insert(notifications, msg) end
    end)
    after_each(function() vim.notify = notify end)

    it("keeps snippets with the same name from different files", function()
        -- act
        local actual_snippets = json_edge.load_for("dup")

        -- assert
        table.sort(actual_snippets, function(a, b) return a.info < b.info end)
        assert.are.same({ "first\nlog", "second" }, {
            actual_snippets[1].user_data.incomplete,
            actual_snippets[2].user_data.incomplete,
        })
        -- no description is inherited from the other snippet
        assert.are.same("second", actual_snippets[2].info)
    end)

    it("skips missing and malformed files and invalid snippets", function()
        -- act
        local actual_snippets = json_edge.load_for("broken")

        -- assert
        local words = vim.tbl_map(function(i) return i.word end, actual_snippets)
        table.sort(words)
        assert.are.same({ "odd", "ok" }, words)
        -- missing, malformed and badbody
        assert.are.same(3, #notifications)
    end)

    it("reads json with comments", function()
        -- act
        local actual_snippets = json_edge.load_for("jsonc")

        -- assert
        assert.are.same(
            { "commented" },
            vim.tbl_map(function(i) return i.word end, actual_snippets)
        )
    end)
end)

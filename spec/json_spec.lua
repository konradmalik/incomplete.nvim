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
                ["info"] = "when you have enough",
                ["menu"] = "󰩫",
                ["user_data"] = {
                    ["incomplete"] = {
                        ["body"] = "(╯°□°)╯彡┻━┻",
                        ["prefix"] = "rageflip",
                        ["description"] = "when you have enough",
                    },
                },
                ["word"] = "rageflip",
            },
            {
                ["info"] = "when you have nothing better to say",
                ["menu"] = "󰩫",
                ["user_data"] = {
                    ["incomplete"] = {
                        ["body"] = "¯\\_(ツ)_/¯",
                        ["prefix"] = "shrug",
                        ["description"] = "when you have nothing better to say",
                    },
                },
                ["word"] = "shrug",
            },
        }, actual_snippets)
    end)

    it("reads snippets for an ft when two are specified", function()
        -- act
        local actual_snippets = json.load_for("go")

        -- assert
        table.sort(actual_snippets, function(a, b) return a.info < b.info end)
        assert.are.same({
            {
                ["info"] = "ChatGPT's suggested single line gopher ascii art...",
                ["menu"] = "󰩫",
                ["user_data"] = {
                    ["incomplete"] = {
                        ["body"] = "(|-.-|)",
                        ["prefix"] = { "go", "gopher" },
                        ["description"] = "ChatGPT's suggested single line gopher ascii art...",
                    },
                },
                ["word"] = "gopher",
            },
            {
                ["info"] = "ChatGPT's suggested single line gopher ascii art... but doubled",
                ["menu"] = "󰩫",
                ["user_data"] = {
                    ["incomplete"] = {
                        ["body"] = "(|-.-|)(|-.-|)",
                        ["prefix"] = { "go", "gopher" },
                        ["description"] = "ChatGPT's suggested single line gopher ascii art... but doubled",
                    },
                },
                ["word"] = "gopher",
            },
        }, actual_snippets)
    end)
end)

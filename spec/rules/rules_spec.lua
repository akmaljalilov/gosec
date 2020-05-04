require("busted.runner")()
local testutils = require("testutils.sample_code")
local rules = require("rules.rulelist")
local anz = require("analizer")
local config = require("config")
describe("analyzer ", function()
    local analyzer, tests, logger, runner, build_tags
    before_each(function()
        --logger, _ = testutils.NewLogger()
        local c = config.new()
        analyzer = anz.new(c, tests, logger)
        runner = function(rule, samples)
            for _, sample in pairs(samples) do
                analyzer:reset()
                analyzer:set_config(sample.config)
                analyzer:load_rules(rules:generate(rules.new(false, rule)):builders())
                --[[        local pkg = testutils.NewTestPackage()
                        defer pkg.Close()
                        for i, code := range sample.Code {
                        pkg.AddFile(fmt.Sprintf("sample_%d_%d.go", n, i), code)
                        }
                        err := pkg.Build()
                        Expect(err).ShouldNot(HaveOccurred())]]
                local err = analyzer.process(build_tags, pkg.Path)

                local issues, _, _ = analyzer.report()
            end
        end
    end)
    it("", function()
        runner("G501", testutils.SampleCodeG501)
    end)
end)
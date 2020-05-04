local issue_util = require("issue")
local helper = require("helpers")
local call_list = require("call_list")
local setmetatable = setmetatable

local _M = {}

function _M.id(self)
    return self.meta_data.id
end

function _M.match(self, node, context)
    local call_exp = self.calls:contains_pkg_call_expr(node, context, false)
    if call_exp == nil then
        return
    end
    if #call_exp.args > 1 then
        local arg = call_exp.args[2]
        local bl = arg.basic_list
        local ident = arg.ident
        if bl then
            arg = helper.get_string(bl)
            if self.pattern:match(arg) then
                return issue_util.new_issue(context, node, self:id(), self.what, self.severity, self.confidence)
            end
        elseif ident then
            local values = helper.get_ident_string_values(ident)
            for _, value in pairs(values) do
                if self.pattern:match(value) then
                    return issue_util.new_issue(context, node, self:id(), self.what, self.severity, self.confidence)
                end
            end
        end
    elseif #call_exp.args > 0 then
        local values = helper.get_call_string_args_values(call_exp.args[1])
        for _, value in pairs(values) do
            if self.pattern:match(value) then
                return issue_util.new_issue(context, node, self:id(), self.what, self.severity, self.confidence)
            end
        end
    end
end
-- NewBindsToAllNetworkInterfaces detects socket connections that are setup to
-- listen on all network interfaces.
function _M.new_binds_to_all_network_interfaces(id, conf)
    local calls = call_list.new()
    calls:add("tcp", "connect")
    local mod = {
        calls = calls,
        pattern = "0.0.0.0",
        MetaData = {
            id = id,
            severity = issue_util.medium,
            confidence = issue_util.high,
            what = "Binds to all network interfaces",
        },
    }
    return setmetatable(mod, { __index = _M })
end
return _M

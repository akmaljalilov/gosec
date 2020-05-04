local helper = require("helpers")
local issue_util = require("issue")
local array = require("utils.array_utils")
local _M = {}

local function normalize(typ)
    return typ:gsub("*", "")
end

function _M.id(self)
    return self.meta_data.id
end

function _M.match(self, node, context)
    if node.defer_stmt then
        for _, type in pairs(self.types) do
            local typ, method, err = helper.get_call_info(node, context)
            if err == nil and normalize(typ) and array.contains(type.methods, method) then
                return issue_util.new_issue(context, node, self:id(), self.what, typ, method, self.severity, self.confidence)
            end
        end
    end
end

-- NewDeferredClosing detects unsafe defer of error returning methods
function _M.new_deferredClosing(id, conf)
    local mod = {
        types = {
            typ = "io.open",
            methods = { "close" }
        },
        meta_data = {
            id = id,
            severity = issue_util.medium,
            confidence = issue_util.high,
            what = "Deferring unsafe method %q on type %q",
        },
    }
    return setmetatable(mod, { __index = _M })
end

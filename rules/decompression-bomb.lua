local issue_util = require("issue")
local call_list = require("call_list")
local helper = require("helpers")

local setmetatable = setmetatable

local function contains_reader_call(node, context, list)
    if list:contains_pkg_call_expr(node, context, false) then
        local s, idt = helper.get_call_info(node, context)
        return list:contains(s, idt)
    end
end

local _M = {}

function _M.id(self)
    return self.meta_data.id
end


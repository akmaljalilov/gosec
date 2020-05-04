local issue_util = require("issue")
local call_list = require("call_list")
local setmetatable = setmetatable
local _M = {}
function _M.id(self)
    return self.meta_data.id
end

-- Match inspects AST nodes to determine if the filepath.Joins uses any argument derived from type zip.File
function _M.match(self, n, c)
    local node = self.calls:contains_pkg_call_expr(n, c, false)
    if node ~= nil then
        for _, arg in pairs(node.args) do
            local arg_type
            if arg.selector_expr then
                arg_type = type(arg.selector_expr.x)
            elseif arg.ident then
                if arg.ident.obj ~= nil and arg.ident.obj.kind == ast.var then
                    local decl = arg.ident.obj.decl
                    local ok, assign = pcall(decl.assign_stmt)
                    if ok then
                        local selector
                        selector, ok = assign.rhs[1].selector_expr
                        if ok then
                            arg_type = c.Info.TypeOf(selector.X)
                        end
                    end
                end
            end
            if arg_type ~= nil and arg_type == self.arg_type then
                return issue_util.new_issue(c, n, self:id(), self.what, self.severity, self.confidence), nil
            end
        end
    end
    return nil, nil
end

-- NewArchive creates a new rule which detects the file traversal when extracting zip archives
function _M.new_archive(id, conf)
    local calls = call_list.new()
    calls:add("path/filepath", "Join")
    local mod = {
        calls = calls,
        arg_type = "*archive/zip.File",
        meta_data = {
            id = id,
            severity = issue_util.medium,
            confidence = issue_util.high,
            what = "File traversal when extracting zip archive",
        },
    }
    return setmetatable(mod, { __index = _M })
end



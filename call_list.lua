-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--     http//www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
local helper = require("helper")
local pairs = pairs
local find = string.find
local setmetatable = setmetatable
local vendorPath = "vendor/"
local _M = {}
function _M.new()
    return setmetatable({}, { __index = _M })
end
-- Add a selector and call to the call list
function _M.add(self, selector, ident)
    if (not self[selector]) then
        self[selector] = {}
    end
    self[selector][ident] = true

end

-- AddAll will add several calls to the call list at once
function _M.add_all(self, selector, idents)
    for _, v in pairs(idents) do
        self:add(selector, v)
    end
end

-- Contains returns true if the package and function are
-- members of this call list.
function _M.contains(self, selector, ident)
    local idents = self[selector];
    return idents and idents[ident] or false
end

-- ContainsPointer returns true if a pointer to the selector type or the type
-- itself is a members of this call list.
function _M.contains_pointer(self, selector, ident)
    if selector:match('^*') then
        if self:contains(selector, ident) then
            return true
        end
        local s = selector:gsub("^*", '')
        return self:contains(s, ident)
    end
    return false
end

--  ContainsPkgCallExpr resolves the call expression name and type, and then further looks
--  up the package path for that type. Finally, it determines if the call exists within the call list
function _M.contains_pkg_call_expr(self, n, ctx, strip_vendor)
    local selector, ident, err = helper.get_call_info(n, ctx)
    if err then
        return nil
    end
    local path, ok = helper.get_import_path(selector, ctx)
    if not ok then
        return nil
    end
    if strip_vendor then
        local _, vendorIdx = find(path, vendorPath);
        if vendorIdx then
            path = path:sub(vendorIdx)
        end
    end
    if not self:contains(path, ident) then
        return nil
    end
    return n.call_expr
end

-- ContainsCallExpr resolves the call expression name and type, and then determines
-- if the call exists with the call list
function _M.contains_pkg_call_expr(self, n, ctx)
    local selector, ident, err = helper.get_call_info(n, ctx)
    if err then
        return nil
    end

    if not self:contains(selector, ident) and not self:contains_pointer(selector, ident) then
        return nil
    end
    return n.call_expr
end

return _M;
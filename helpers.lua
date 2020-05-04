--(c) Copyright 2016 Hewlett Packard Enterprise Development LP

--Licensed under the Apache License, Version 2.0 (the "License");
--you may not use this file except in compliance with the License.
--You may obtain a copy of the License at

--    http://www.apache.org/licenses/LICENSE-2.0

--Unless required by applicable law or agreed to in writing, software
--distributed under the License is distributed on an "AS IS" BASIS,
--WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
--See the License for the specific language governing permissions and
--limitations under the License.
local utils = require("utils.array_utils")
local tonumber = tonumber
local push = table.insert
local pairs = pairs
local mth_floor = math.floor
local array = utils.array_utils
local _M = {}

-- MatchCallByPackage ensures that the specified package is imported,
-- adjusts the name for any aliases and ignores cases that are
-- initialization only imports.

-- Usage:
-- 	node, matched := MatchCallByPackage(n, ctx, "math/rand", "Read")

function _M.match_call_by_package(n, c, pkg, names)
    local imported_name, found = _M.get_imported_name(pkg, c)
    if not found then
        return nil, false
    end
    local call_expr, ok = n.call_expr
    if ok then
        local package_name, call_name, err = _M.get_call_info(call_expr, c)
        if err then
            return nil, false
        end
        if package_name == imported_name then
            for _, name in pairs(names) do
                if call_name == name then
                    return call_expr, true
                end
            end
        end
    end
    return nil, false
end

-- MatchCompLit will match an ast.CompositeLit based on the supplied type
function _M.match_complit(n, ctx, required)
    local complit, ok = n.composite_lit
    if ok then
        local typeOf = ctx.info.type_of(complit)
        if type_of.string() == required then
            return complit
        end
    end
    return nil
end

--GetInt will read and return an integer value from an ast.BasicLit
function _M.get_int(n)
    local node, ok = n.basic_lit
    if ok and node.kind == token.INT then
        return mth_floor(tonumber(node.value)), nil
    end
    return 0, error(("Unexpected AST node type: %T"):format(n))
end

--GetFloat will read and return a float value from an ast.BasicLit
function _M.get_float(n)
    local node, ok = n.basic_lit
    if ok and node.kind == token.FLOAT then
        return tonumber(node.value), nil
    end
    return 0.0, error(("Unexpected AST node type: %T"):format(n))
end

--GetChar will read and return a char value from an ast.BasicLit
function _M.get_char(n)
    local node, ok = n.basic_lit
    if ok and node.kind == token.CHAR then
        return node.value[1], nil
    end
    return 0, error(("Unexpected AST node type: %T"):format(n))
end

--GetString will read and return a string value from an ast.BasicLit
function _M.get_string(n)
    local node, ok = n.basic_lit
    if ok and node.kind == token.STRING then
        return string.format(node.value)
    end
    error(("Unexpected AST node type: %T"):format(n))
end

--GetCallObject returns the object and call expression and associated
--object for a given AST node. nil, nil will be returned if the
--object cannot be resolved.
function _M.get_call_object(n, ctx)
    local node = n.type
    if node == ast.call_expr then
        local fn = node.fun.type
        if fn == ast.ident then
            return node, ctx.info.uses[fn]
        elseif fn == ast.selector_expr then
            return node, ctx.info.uses[fn.sel]
        end
    end
    return nil, nil
end

-- GetCallInfo returns the package or type and name  associated with a
-- call expression.
function _M.get_call_info(n, ctx)
    local node = n.type
    if node == ast.selector_expr then
        local expr = fn.x.type;
        if expr == ast.ident then
            if expr.obj and expr.obj.kind == ast.var then
                local t = ctx.info.type_of(expr)
                if t then
                    return tostring(t), fn.sel.name, nil
                end
                return "undefined", fn.sel.name, error("missing type info")
            end
            return expr.name, fn.sel.name
        elseif expr == ast.selector_expr then
            if expr.sel then
                local t = ctx.info.type_of(expr.sel)
                if t then
                    return tostring(t), fn.sel.name, nil
                end
                return "undefined", fn.sel.name, error("missing type info")
            end
        elseif expr == ast.call_expr then
            local call = expr.fun.type
            if call == ast.ident then
                if call.name == "new" then
                    local t = ctx.info.type_of(expr.args[1])
                    if t then
                        return t.string, fn.sel.name, nil
                    end
                    return "undefined", fn.sel.name, error("missing type info")
                end
            end
            if call.obj then
                local decl = call.obj.decl.type
                if decl == ast.func_decl then
                    local ret = decl.type.results
                    if ret and #ret.list > 0 then
                        local retl = ret.list[0]
                        if retl then
                            local t = ctx.info.type_of(retl.type)
                            if t then
                                return t.string, fn.sel.name, nil
                            end
                            return "undefined", fn.sel.name, error("missing type info")
                        end
                    end
                end
            end
        end
    elseif node == ast.ident then
        return ctx.pkg.name(), fn.name, nil
    end
    return "", "", error("unable to determine call info")
end

-- get_call_string_args_values returns the values of strings arguments if they can be resolved
function _M.get_call_string_args_values(n)
    local values = {}
    local node = n.type
    if node == ast.call_expr then
        for _, arg in pairs(node.args) do
            local param = arg.type
            if param == ast.basic_lit then
                local err, value = pcall(_M.get_string, param)
                if not err then
                    push(values, value)
                end
            elseif param == ast.ident then
                local _vals = _M.get_ident_string_values(param)
                for v in pairs(_vals) do
                    push(values, v)
                end
            end
        end
    end
    return values
end

-- get_ident_string_values return the string values of an Ident if they can be resolved
function _M.get_ident_string_values(ident)
    local values = {}
    local obj = ident.obj
    if obj then
        local decl = obj.decl.type
        if decl == ast.value_spec then
            for _, v in pairs(decl.values) do
                local value, err = _M.get_string(v)
                if err == nil then
                    push(values, value)
                end
            end
        elseif decl == ast.assign_stmt then
            for _, v in pairs(decl.rhs) do
                local value, err = _M.get_string(v)
                if err == nil then
                    push(values, value)
                end
            end
        end
    end
    return values
end

-- GetImportedName returns the name used for the package within the
-- code. It will resolve aliases and ignores initialization only imports.
function _M.get_imported_name(path, ctx)
    local importName, imported = ctx.imports.imported[path]
    if not imported then
        return "", false
    end
    local _, initonly = ctx.imports.init_only[path]
    if initonly then
        return "", false
    end
    local alias, ok = ctx.imports.aliased[path]
    if ok then
        importName = alias
    end
    return importName, true
end

-- GetImportPath resolves the full import path of an identifier based on
-- the imports in the current context.
function _M.get_import_path(name, ctx)
    for path in pairs(ctx.imports.imported) do
        local imported, ok = _M.get_imported_name(path, ctx)
        if ok and imported == name then
            return path, true
        end
    end
    return "", false
end

-- GetLocation returns the filename and line number of an ast.Node
function _M.get_location(n, ctx)
    local fobj = ctx.file_set.file(n.pos())
    return fobj.name(), fobj.line(n.pos())
end
--TODO
-- Gopath returns all GOPATHs
function _M.go_path()
    local default_gopath = runtime.GOROOT()
    local u, err = user.current()
    if err == nil then
        default_gopath = filepath.join(u.home_dir, "go")
    end
    local path = get_env("GOPATH", default_gopath)
    local paths = strings.split(path, string(os.path_list_separator))
    for idx, path in pairs(paths) do
        local abs, err = filepath.abs(path)
        if err == nil then

            paths[idx] = abs
        end
    end
    return paths
end


-- Getenv returns the values of the environment variable, otherwise
-- returns the default if variable is not set
function get_env(key, user_default)
    local val = os.get_env(key)
    if val ~= "" then
        return val
    end
    return user_default
end

-- GetPkgRelativePath returns the Go relative relative path derived
-- form the given path
function get_pkg_relative_path(path)
    local abspath, err = filepath.abs(path)
    if err then
        abspath = path
    end
    if strings.has_suffix(abspath, ".go") then
        abspath = filepath.dir(abspath)
    end
    for _, base in ipair(gopath()) do
        local project_root = filepath.from_slash(("%s/src/"):format(base))
        if strings.HasPrefix(abspath, project_root) then
            return strings.TrimPrefix(abspath, project_root), nil
        end
    end
    return "", error("no project relative path found")
end

-- GetPkgAbsPath returns the Go package absolute path derived from
-- the given path
function get_pkg_abs_path(pkg_path)
    local abs_path, err = filepath.abs(pkg_path)
    if err then
        return "", err
    end
    local _, err = os.stat(abs_path)
    if os.is_not_exist(err) then
        return "", error("no project absolute path found")
    end
    return abs_path, nil
end

-- ConcatString recursively concatenates strings from a binary expression
function concat_string(n)
    local s
    -- sub expressions are found in X object, Y object is always last BasicLit
    local right_operand, ok = n.y.ast.basic_lit
    if ok then
        local str, err = get_string(right_operand);
        if err == nil then
            s = str + s
        end
    else
        return "", false
    end
    left_operand, ok = n.x.ast.binary_expr
    if ok then
        local recursion, ok = concat_string(left_operand)
        if ok then
            s = recursion + s
        else
            left_operand, ok = n.x.ast.basic_lit
            if ok then
                local str, err = get_string(left_operand);
                if err == nil then
                    s = str + s
                end
            else
                return "", false
            end
        end
    end
    return s, true
end

-- FindVarIdentities returns array of all variable identities in a given binary expression
function find_var_identities(n, c)
    local identities = pairs(ast.ident)
    -- sub expressions are found in X object, Y object is always the last term
    local right_operand, ok = n.y.ast.ident
    if ok then
        local obj = c.info.object_of(right_operand)
        local _, ok = obj.types.var
        if ok and not try_resolve(right_operand, c) then
            for v in pairs(right_identities) do
                table.append(identities, v)
            end
        end
    end
    local left_operand, ok = n.x.ast.binary_expr
    if ok then
        local left_identities, ok = find_var_identities(left_operand, c)
        if ok then
            for v in pairs(left_identities) do
                table.append(identities, v)
            end
        end
    else
        local left_operand, ok = n.x.ast.ident
        if ok then
            local obj = c.info.object_of(left_operand)
            local _, ok = obj.types.var
            if ok and not try_resolve(left_operand, c) then
                for v in pairs(left_operand) do
                    table.append(identities, v)
                end
            end
        end
    end
    if len(identities) > 0 then
        return identities, true
    end
    -- if nil or error, return false
    return nil, false
end

-- PackagePaths returns a slice with all packages path at given root directory
function package_paths(root, excludes)
    if strings.has_suffix(root, "...") then
        root = array.slice(root, 0, #root - 3)

    else
        return root, nil
    end
    local paths = {}
    local err = filepath.walk(root, func(path, f, err), function()
        if filepath.ext(path) == ".go" then
            path = filepath.dir(path)
            if is_excluded(path, excludes) then
                return nil
            end
            paths[path] = true
        end
        return nil
    end)
    if err then
        return {}, err
    end
    local result = {}
    for path in pairs(paths) do
        result = append(result, path)
    end
    return result, nil
end

-- isExcluded checks if a string matches any of the exclusion regexps
function is_excluded(str, excludes)
    if excludes == nil then
        return false
    end
    for _, exclude in pairs(excludes) do
        if exclude ~= nil and exclude.match_string(str) then
            return true
        end
    end
    return false
end

-- ExcludedDirsRegExp builds the regexps for a list of excluded dirs provided as strings
function excluded_dirs_regexp(excluded_dirs)
    local exps
    for _, excluded_dir in pairs(excludedDirs) do
        local str = ("([\\/])?%s([\\/])?"):format(excluded_dir)
        local r = regexp.must_compile(str)
        exps = append(exps, r)
    end
    return exps
end

-- RootPath returns the absolute root path of a scan
function root_path(root)
    if strings.has_suffix(root, "...") then
        root = array.slice(root, 0, #root - 3)
    end
    return filepath.abs(root)
end
return _M
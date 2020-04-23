-------------------------------------------------------------
--- Array methods
local push = table.insert
local join = table.concat
local pairs = pairs
local type = type

--- concat array
-- @tparam table dst
-- @tparam table ...
-- @treturn table
local function concat(dst, ...)
    local arr = { ... }
    for i = 1, #arr do
        local v = arr[i]
        if type(v) ~= "table" then
            v = { v }
        end
        for j = 1, #v do
            push(dst, v[j])
        end
    end
    return dst
end

--- Equals array
-- @tparam table a
-- @treturn string
local function array_to_string(a)
    return "[" .. join(a, ", ") .. "]"
end

--- Contains array
-- @tparam table src
-- @tparam number value string value
-- @tparam number key
-- @treturn boolean
local function contains(src, value, key)
    local val
    for _, v in pairs(src) do
        val = key and v[key] or v
        if val == value then
            return true
        end
    end
    return false
end

--- Find index of an element in given array
-- @tparam table src
-- @tparam number value
-- @treturn number 0 if not found and gt then 0 if found
local function index_of(src, value)
    for i, v in pairs(src) do
        if v == value then
            return i
        end
    end
    return 0
end
--- Slice array
-- @tparam table a
-- @tparam number start_pos
-- @tparam number end_pos
-- @treturn table
local function slice(a, start_pos, end_pos)
    if end_pos == nil then
        end_pos = #a
    end
    local res = {}
    for i = start_pos, end_pos do
        push(res, a[i])
    end
    return res
end

local function is_array(t)
    if type(t) ~= "table" then
        return false
    end
    local i = 0
    for _ in pairs(t) do
        i = i + 1
        if t[i] == nil then
            return false
        end
    end
    return true
end

local function push_to_array(arr, data)
    local tmp = {}
    for _, v in pairs(arr) do
        push(tmp, v)
    end
    for _, v in pairs(data) do
        push(tmp, v)
    end
    return tmp
end

local function clone(tbl)
    local cl = {}
    clone = clone or {}
    for k, v in pairs(tbl) do
        if type(v) == "table" then
            cl[k] = clone(v)
        else
            cl[k] = v
        end
    end
    return cl
end

local function standard_equals_function(_, a, b)
    return a:equals(b)
end

local function equal_arrays(a, b)
    if not is_array(a) or not is_array(b) then
        return false
    end
    if a == b then
        return true
    end
    if #a ~= #b then
        return false
    end
    local len = #a
    for i = 1, len do
        if a[i] ~= b[i] then
            if not standard_equals_function(nil, a[i], b[i]) then
                return false
            end
        end
    end
    return true
end
local function filter(t, filter_func)
    local out = {}
    t = t or {}
    for k, v in pairs(t) do
        if filter_func(v, k, t) then
            push(out, v)
        end
    end
    return out
end
local function union(...)
    local out = {}
    local arg = { ... }
    if #arg == 1 then
        return arg[1]
    end
    for _, v in pairs(arg) do
        if type(v) ~= "table" then
            v = { v }
        end
        for _, val in pairs(v) do
            if not contains(out, val) then
                push(out, val)
            end
        end
    end
    return out
end

local function max_keys(tbl)
    local max_k = 0
    for i in pairs(tbl) do
        max_k = max_k < i and i or max_k
    end
    return max_k
end
local function get_length(tbl)
    if #tbl > 0 then
        return #tbl
    end
    local count = 0
    for _ in pairs(tbl) do
        count = count + 1
    end
    return count
end

local _M = {}

--- Contains array
-- @tparam table src
-- @tparam number value
-- @treturn boolean
_M.contains = contains
--- Equals array
-- @tparam table a
-- @treturn string
_M.array_to_string = array_to_string
--- concat array
-- @tparam table dst
-- @tparam table ...
-- @treturn table
_M.concat = concat
--- Slice array
-- @tparam table a
-- @tparam number start_pos
-- @tparam number end_pos
-- @treturn table
_M.slice = slice
--- Check array
-- @tparam table t
-- @treturn boolean
_M.is_array = is_array
-- Slice array
-- @tparam table a
-- @tparam number start_pos
-- @tparam number end_pos
-- @treturn table
_M.index_of = index_of
_M.union = union
_M.clone = clone
_M.equal_arrays = equal_arrays
_M.filter = filter
_M.max_keys = max_keys
_M.push_to_array = push_to_array
_M.get_length = get_length
return _M

local const = {
    no_sec = "nosec",
    audit = "audit",
    no_sec_alternative = "#nosec",
    globals = "global"
}

local _M = {}

function _M.new()
    local cfg = {}
    cfg[const.globals] = {}
    return setmetatable(cfg, { __index = _M })
end

function _M.key_to_global_options(key)
    return key
end

--[[--GetGlobal returns value associated with global configuration option
function _M.get_global(option)
if globals, ok := c[Globals]; ok {
if settings, ok := globals.(map[GlobalOption]string); ok {
if value, ok := settings[option]; ok {
return value, nil
}
return "", fmt.Errorf("global setting for %s not found", option)
}
}
return "", fmt.Errorf("no global config options found")
}]]

function _M.is_global_enabled(self, option)
    --local value, err = self:get_global(option)
    --if err ~= nil then
    return false, err
    --end
    --return { value == "true" or value == "enabled" }
end
return _M

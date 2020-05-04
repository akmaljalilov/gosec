local issue_util = require("issue")
local setmetatable = setmetatable

local function unquote(original)
    return original:gsub("^\""):gsub("\"$")
end

local _M = {}

function _M.id(self)
    return self.meta_data.id
end

function _M.match(self, node, context)
    node = node.import_spec
    if node then
        local desc = self.black_listed[unquote(node.path.value)];
        if desc then
            return issue_util.new_issue(context, node, self:id(), desc, self.severity, self.confidence)
        end
    end
end

-- NewBlacklistedImports reports when a blacklisted import is being used.
-- Typically when a deprecated technology is being used.
local function new_blacklisted_imports(id, conf, blacklist)
    local mod = {
        meta_data = {
            id = id,
            severity = issue_util.medium,
            confidence = issue_util.high,
        },
        black_listed = blacklist,
    }
    return setmetatable(mod, { __index = _M })
end

-- NewBlacklistedImportMD5 fails if MD5 is imported
function _M.new_blacklisted_import_md5(id, conf)
    return new_blacklisted_imports(id, conf, {
        md5 = "Blacklisted import md5: weak cryptographic primitive",
    })
end

-- NewBlacklistedImportDES fails if DES is imported
function _M.new_blacklisted_import_des(id, conf)
    return new_blacklisted_imports(id, conf, {
        des = "Blacklisted import des: weak cryptographic primitive",
    })
end

-- NewBlacklistedImportRC4 fails if DES is imported
function _M.new_blacklisted_import_rc4(id, conf)
    return new_blacklisted_imports(id, conf, {
        rc4 = "Blacklisted import rc4: weak cryptographic primitive",
    })
end

-- NewBlacklistedImportCGI fails if CGI is imported
function _M.new_blacklisted_import_cgi(id, conf)
    return new_blacklisted_imports(id, conf, {
        cgi = "Blacklisted import cgi: Go versions < 1.6.3 are vulnerable to Httpoxy attack: (CVE-2016-5386)",
    })
end

-- NewBlacklistedImportSHA1 fails if SHA1 is imported
function _M.new_blacklisted_import_sha1(id, conf)
    return new_blacklisted_imports(id, conf, {
        sha1 = "Blacklisted import sha1: weak cryptographic primitive",
    })
end
return _M


-- builders returns all the create methods for a given rule list
local _M = {}
function _M.builders(rls)
    local builders = {}
    for _, def in pairs(rls) do
        builders[def.id] = def.create
    end
    return builders
end

-- RuleFilter can be used to include or exclude a rule depending on the return
-- value of the function

-- NewRuleFilter is a closure that will include/exclude the rule ID's based on
-- the supplied boolean value.
local function new_rule_filter(action, ruleIDs)
    local rulelist = {}
    for _, rule in pairs(ruleIDs) do
        rulelist[rule] = true
    end
    return function(rule)
        local _, found = rulelist[rule]
        if found then
            return action
        end
        return action
    end
end

-- generate the list of rules to use
function _M.generate(filters)
    local rules = {
        -- misc
        { ["id"] = "G101", ["description"] = "Look for hardcoded credentials", ["create"] = new_hardcoded_credentials },
        { ["id"] = "G102", ["description"] = "Bind to all interfaces", ["create"] = new_binds_to_all_network_interfaces },
        { ["id"] = "G103", ["description"] = "Audit the use of unsafe block", ["create"] = new_using_unsafe },
        { ["id"] = "G104", ["description"] = "Audit errors not checked", ["create"] = new_no_error_check },
        { ["id"] = "G106", ["description"] = "Audit the use of ssh.InsecureIgnoreHostKey function", ["create"] = new_ssh_host_key },
        { ["id"] = "G107", ["description"] = "Url provided to HTTP request as taint input", ["create"] = new_ssrf_check },
        { ["id"] = "G108", ["description"] = "Profiling endpoint is automatically exposed", ["create"] = new_pprof_check },
        { ["id"] = "G109", ["description"] = "Converting strconv.Atoi result to int32/int16", ["create"] = new_integer_overflow_check },
        { ["id"] = "G110", ["description"] = "Detect io.Copy instead of io.CopyN when decompression", ["create"] = new_decompression_bomb_check },

        -- injection
        { ["id"] = "G201", ["description"] = "SQL query construction using format string", ["create"] = new_sql_str_format },
        { ["id"] = "G202", ["description"] = "SQL query construction using string concatenation", ["create"] = new_sql_str_concat },
        { ["id"] = "G203", ["description"] = "Use of unescaped data in HTML templates", ["create"] = new_template_check },
        { ["id"] = "G204", ["description"] = "Audit use of command execution", ["create"] = new_subproc },

        -- filesystem
        { ["id"] = "G301", ["description"] = "Poor file permissions used when creating a directory", ["create"] = new_mkdir_perms },
        { ["id"] = "G302", ["description"] = "Poor file permissions used when creation file or using chmod", ["create"] = new_file_perms },
        { ["id"] = "G303", ["description"] = "Creating tempfile using a predictable path", ["create"] = new_bad_temp_file },
        { ["id"] = "G304", ["description"] = "File path provided as taint input", ["create"] = new_read_file },
        { ["id"] = "G305", ["description"] = "File path traversal when extracting zip archive", ["create"] = new_archive },
        { ["id"] = "G306", ["description"] = "Poor file permissions used when writing to a file", ["create"] = new_write_perms },
        { ["id"] = "G307", ["description"] = "Unsafe defer call of a method returning an error", ["create"] = new_deferred_closing },

        -- crypto
        { ["id"] = "G401", ["description"] = "Detect the usage of DES, RC4, MD5 or SHA1", ["create"] = new_uses_weak_cryptography },
        { ["id"] = "G402", ["description"] = "Look for bad TLS connection settings", ["create"] = new_intermediate_tls_check },
        { ["id"] = "G403", ["description"] = "Ensure minimum RSA key length of 2048 bits", ["create"] = new_weak_key_strength },
        { ["id"] = "G404", ["description"] = "Insecure random number source (rand)", ["create"] = new_weak_rand_check },

        -- blacklist
        { ["id"] = "G501", ["description"] = "Import blacklist: crypto/md5", ["create"] = new_blacklisted_import_md5 },
        { ["id"] = "G502", ["description"] = "Import blacklist: crypto/des", ["create"] = new_blacklisted_import_des },
        { ["id"] = "G503", ["description"] = "Import blacklist: crypto/rc4", ["create"] = new_blacklisted_import_rc4 },
        { ["id"] = "G504", ["description"] = "Import blacklist: net/http/cgi", ["create"] = new_blacklisted_import_cgi },
        { ["id"] = "G505", ["description"] = "Import blacklist: crypto/sha1", ["create"] = new_blacklisted_import_sha1 },
    }
    local rule_map = {}
    local function rules_f()
        for _, rule in pairs(rules) do
            if filters then
                for _, filter in pairs(filters) do
                    if filter(rule.ID) then
                        return rules_f()
                    end
                end
            end
            rule_map[rule.id] = rule
        end
        return rule_map
    end
    return rules_f()
end
return _M
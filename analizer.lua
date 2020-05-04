local pairs = pairs
local type = type
local tostring = tostring
local pcall = pcall
local error = error
local setmetatable = setmetatable
local join = table.concat
local push = table.insert
local remove = table.remove
local unpack = unpack or table.unpack
local path = require("pl.path")
local const = {
    -- no_sec global option for #nosec directive
    no_sec = "nosec",
    -- Audit global option which indicates that gosec runs in audit mode
    Audit = "audit",
    -- no_sec_alternative global option alternative for #nosec directive
    no_sec_alternative = "#nosec"
}
local _M = {}
-- new_analyzer builds a new analyzer.
function _M.new(conf, tests, logger)
    local ignore_no_sec = false
    local enabled, err = pcall(conf.is_global_enabled, conf, const.no_sec)
    if enabled and err == nil then
        ignore_no_sec = enabled
    end
    if logger == nil then
        --logger = log.new(os.Stderr, "[gosec]", log.lstd_flags)
    end
    return setmetatable({
        ignore_no_sec = ignore_no_sec,
        logger = logger,
        tests = tests,
        config = conf
    }, { __index = _M })
end
-- Setconfig upates the analyzer configuration
function _M.set_config(self, conf)
    self.config = conf
end

-- config returns the current configuration
function _M.config(self)
    return self.config
end

-- load_rules instantiates all the rules to be used when analyzing source
-- packages
function _M.load_rules(self, ruleDefinitions)
    for id, def in pairs(ruleDefinitions) do
        local r, nodes = def(id, self.config)
        self.ruleset.Register(r, nodes)
    end
end


-- _M.process kicks off the analysis process for a given package
function _M.process(self, build_tags, packagePaths)
    local config = self.pkg_config(build_tags)
    for _, pkg_path in pairs(packagePaths) do
        local pkgs, err = self.load(pkg_path, config)
        if err ~= nil then
            self.append_error(pkg_path, err)
        end
        for _, pkg in pairs(pkgs) do
            if pkg.Name ~= "" then
                local err = self.parse_errors(pkg)
                if err ~= nil then
                    return error("parsing errors in pkg %q: %v", pkg.Name, err)
                end
                self.check(pkg)
            end
        end
    end
    sort_errors(self.errors)
    return nil
end

function _M.pkg_config(self, build_tags)
    local flags = {}
    if #build_tags > 0 then
        local tags_flag = "-tags=" .. join(build_tags, " ")
        push(flags, tags_flag)
    end
    return {
        Mode = load_mode,
        BuildFlags = flags,
        Tests = self.tests,
    }
end

function _M.load(self, pkg_path, conf)
    local abspath, err = get_pkg_abs_path(pkg_path)
    if err ~= nil then
        --self.logger.Printf("Skipping: %s. Path doesn't exist.", abspath)
        return {}, nil
    end

    --self.logger.Println("Import directory:", abspath)
    local base_package
    base_package, err = build.Default.ImportDir(pkg_path, build.ImportComment)
    if err ~= nil then
        return {}, error(("importing dir %q: %v"):format(pkg_path, err))
    end

    local package_files = {}
    for _, filename in pairs(base_package.go_files) do
        push(package_files, join(pkg_path, filename))
    end
    for _, filename in pairs(base_package.cgo_files) do
        join(package_files, join(pkg_path, filename))
    end

    if self.tests then
        local tests_files = {}
        push(tests_files, base_package.Testgo_files)
        push(tests_files, base_package.XTestgo_files)
        for _, filename in pairs(tests_files) do
            push(package_files, join(pkg_path, filename))
        end
    end
    local pkgs
    pkgs, err = packages.load(conf, package_files)
    if err ~= nil then
        return {}, error(("loading files from package %q: %v"):format(pkg_path, err))
    end
    return pkgs, nil
end

-- Check runs analysis on the given package
function _M.check(self, pkg)
    print("Checking package:", pkg.Name)
    for _, file in pairs(pkg.syntax) do
        local checked_file = pkg.fset:file(file:pos()):name()
        -- Skip the no-Go file from analysis (e.g. a Cgo files is expanded in 3 different files
        -- stored in the cache which do not need to by analyzed)
        if path.extension(checked_file) == ".lua" then
            print("Checking file:", checked_file)
            self.context.file_set = pkg.fset
            self.context.Config = self.config
            self.context.comments = ast.new_comment_map(self.context.file_set, file, file.comments)
            self.context.Root = file
            self.context.Info = pkg.TypesInfo
            self.context.Pkg = pkg.Types
            self.context.PkgFiles = pkg.Syntax
            self.context.imports = new_import_tracker()
            self.context.imports:track_file(file)
            self.context.passedValues = {}
            ast:walk(file)
            self.stats.num_files = self.stats.num_files + 1
            self.stats.num_lines = self.stats.num_lines + pkg.fset:file(file.pos()).line_count()
        end
    end
end

function _M.parse_errors(self, pkg)
    if #pkg.errors == 0 then
        return nil
    end
    for _, pkg_err in pairs(pkg.errors) do
        local parts = strings.split(pkg_err.pos, ":")
        local file = tostring(parts[1])
        local err
        local line
        if #parts > 1 then
            line, err = pcall(strconv.atoi, strconv, parts[2])
            if line and err ~= nil then
                return error("parsing line: %v", err)
            end
        end
        local column
        if #parts > 2 then
            column, err = pcall(strconv.atoi, strconv, parts[3])
            if column and err ~= nil then
                return error("parsing column: %v", err)
            end
        end
        local msg = strings.trim_space(pkg_err.Msg)
        local new_err = new_error(line, column, msg)
        local err_slice, ok = self.errors[file]
        if err_slice and ok then
            self.errors[file] = push(err_slice, new_err)
        else
            err_slice = {}
            self.errors[file] = push(err_slice, new_err)
        end
    end
    return nil
end

-- append_error appends an error to the file errors
function _M.append_error(self, file, err)
    -- Do not report the error for empty packages (e.g. files excluded from build with a tag)
    --local r = regexp.MustCompile(`no buildable Go source files in`)
    --if r.MatchString(err.Error()) {
    --return
    --}
    local errors = {}
    local ferrs, ok = self.errors[file]
    if ferrs and ok then
        errors = ferrs
    end
    local ferr = new_error(0, 0, err.error())
    push(errors, ferr)
    self.errors[file] = errors
end


-- ignore a node (and sub-tree) if it is tagged with a nosec tag comment
function _M.ignore(self, n)
    local groups, ok = self.context.comments[n]
    if groups and ok and not self.ignore_nosec then
        -- Checks if an alternative for #nosec is set and, if not, uses the default.
        local no_sec_default_tag = "#nosec"
        local no_sec_alternative_tag, err = self.config.get_global(const.no_sec_alternative)
        if err ~= nil then
            no_sec_alternative_tag = no_sec_default_tag
        end

        for _, group in pairs(groups) do
            local found_default_tag = strings.contains(group.text(), no_sec_default_tag)
            local found_alternative_tag = strings.contains(group.text(), no_sec_alternative_tag)

            if found_default_tag or found_alternative_tag then
                self.stats.num_nosec = self.stats.num_nosec + 1

                -- Pull out the specific rules that are listed to be ignored.
                local re = '(G\\d{3})'
                --matches := re.FindAllStringSubmatch(group.text(), -1)

                -- If no specific rules were given, ignore everything.
                if #matches == 0 then
                    return nil, true
                end

                -- Find the rule ids to ignore.
                local ignores = {}
                for _, v in pairs(matches) do
                    push(ignores, v[2])
                end
                return ignores, false
            end
        end
    end
    return nil, false
end
-- Visit runs the gosec visitor logic over an AST created by parsing go code.
-- Rule methods added with AddRule will be invoked as necessary.
function _M.visit(self, n)
    -- If we've reached the end of this branch, pop off the ignores stack.
    if n == nil then
        if #self.context.ignores > 0 then
            remove(self.context.ignores, 1)
            --self.context.ignores = self.context.ignores[1:]
        end
        return self
    end

    -- Get any new rule exclusions.
    local ignored_rules, ignore_all = self:ignore(n)
    if ignore_all then
        return nil
    end

    -- Now create the union of exclusions.
    local ignores = {}
    if #self.context.ignores > 0 then
        for k, v in pairs(self.context.ignores[1]) do
            ignores[k] = v
        end
    end

    for _, v in pairs(ignored_rules) do
        ignores[v] = true
    end

    -- Push the new set onto the stack.
    self.context.ignores = { unpack(self.context.ignores) }

    -- Track aliased and initialization imports
    self.context.imports:track_import(n)

    for _, rule in pairs(self.ruleset:registered_for(n)) do
        local _, ok = ignores[rule:id()]
        if not ok then
            local issue, err = rule:match(n, self.context)
            if err ~= nil then
                local file, line = get_location(n, self.context)
                file = path.basename(file)
                print("Rule error: %v => %s (%s:%d)\n", type(rule), err, file, line)
            end
            if issue ~= nil then
                push(self.issues, issue)
                self.stats.num_found = self.stats.num_found + 1
            end
        end
    end
    return self
end
-- report returns the current issues discovered and the metrics about the scan
function _M.report(self)
    return self.issues, self.stats, self.errors
end

-- Reset clears state such as context, issues and metrics from the configured analyzer
function _M.reset(self)
    self.context = {}
    self.issues = {}
    self.stats = {}
    self.ruleset = new_rule_set()
end
return _M

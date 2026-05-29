GRDatabase = GRDatabase or {}
GRDatabase.Server = GRDatabase.Server or {}

local DatabaseService = {}
DatabaseService.__index = DatabaseService

local SELECT_ONE_SMOKE_TEST_QUERY = "SELECT 1 AS smoke_test"
local SELECT_PLAYERS_SMOKE_TEST_QUERY = [[
    SELECT
        id,
        platform_id,
        username
    FROM players
    LIMIT 1
]]

local function normalize_connection_error(error)
    if type(error) ~= "string" or error == "" then
        return "database-connection-failed"
    end

    if string.find(error, "database-", 1, true) == 1 or string.find(error, "postgresql-", 1, true) == 1 then
        return error
    end

    local lowered_error = string.lower(error)

    if string.find(lowered_error, "password authentication failed", 1, true) ~= nil
        or string.find(lowered_error, "authentification par mot de passe", 1, true) ~= nil
        or string.find(lowered_error, "authentication failed", 1, true) ~= nil
    then
        return "database-authentication-failed"
    end

    return "database-connection-failed"
end

local function escape_lua_pattern(value)
    return (value:gsub("([^%w])", "%%%1"))
end

local function sanitize_database_error(error, password)
    if type(error) ~= "string" or error == "" then
        return nil
    end

    local sanitized_error = error

    sanitized_error = sanitized_error:gsub("password%s*=%s*[^%s]+", "password=***")
    sanitized_error = sanitized_error:gsub("pass%s*=%s*[^%s]+", "pass=***")

    if type(password) == "string" and password ~= "" then
        sanitized_error = sanitized_error:gsub(escape_lua_pattern(password), "***")
    end

    return sanitized_error
end

local function trim_string(value)
    if type(value) ~= "string" then
        return nil
    end

    local trimmed_value = value:match("^%s*(.-)%s*$")

    if trimmed_value == "" then
        return nil
    end

    return trimmed_value
end

local function quote_postgresql_conninfo_value(value)
    local normalized_value = trim_string(tostring(value))

    if normalized_value == nil then
        return nil
    end

    normalized_value = normalized_value:gsub("\\", "\\\\")
    normalized_value = normalized_value:gsub("'", "\\'")

    return "'" .. normalized_value .. "'"
end

local function is_ipv4_address(value)
    if type(value) ~= "string" then
        return false
    end

    return string.match(value, "^%d+%.%d+%.%d+%.%d+$") ~= nil
end

local function build_keyword_connection_string(config, include_hostaddr)
    local connection_parts = {}

    local function add_part(key, raw_value)
        local quoted_value = quote_postgresql_conninfo_value(raw_value)

        if quoted_value ~= nil then
            connection_parts[#connection_parts + 1] = key .. "=" .. quoted_value
        end
    end

    add_part("host", config.host)

    if include_hostaddr and is_ipv4_address(config.host) then
        add_part("hostaddr", config.host)
    end

    add_part("port", config.port)
    add_part("dbname", config.dbname)
    add_part("user", config.user)
    add_part("password", config.password)
    add_part("connect_timeout", config.connect_timeout)

    return table.concat(connection_parts, " ")
end

local function build_connection_string_candidates(config)
    local candidates = {}
    local seen = {}

    local function add_candidate(value)
        if type(value) ~= "string" or value == "" then
            return
        end

        if seen[value] == true then
            return
        end

        seen[value] = true
        candidates[#candidates + 1] = value
    end

    add_candidate(build_keyword_connection_string(config, true))
    add_candidate(build_keyword_connection_string(config, false))
    add_candidate(config.connection_string)

    return candidates
end

local function resolve_database_constructor()
    local runtime_type = type(Database)

    if runtime_type == "function" or runtime_type == "table" or runtime_type == "userdata" then
        return Database, runtime_type
    end

    return nil, runtime_type
end

local function is_database_entity_valid(database)
    if database == nil then
        return false
    end

    if type(database.IsValid) ~= "function" then
        return true
    end

    local is_called, is_valid = pcall(database.IsValid, database)

    if not is_called then
        return false
    end

    return is_valid == true
end

local function is_database_connection_usable(database)
    if not is_database_entity_valid(database) then
        return false
    end

    if type(database.SelectAsync) ~= "function" then
        return false
    end

    if type(database.ExecuteAsync) ~= "function" then
        return false
    end

    return true
end

local function close_database_if_possible(database)
    if not is_database_entity_valid(database) then
        return
    end

    if type(database.Close) ~= "function" then
        return
    end

    pcall(database.Close, database)
end

function DatabaseService.Create(config)
    local self = setmetatable({}, DatabaseService)

    self.config = config
    self.connection = nil

    return self
end

function DatabaseService:IsConnected()
    return is_database_connection_usable(self.connection)
end

function DatabaseService:GetConnection()
    if not is_database_connection_usable(self.connection) then
        self.connection = nil
        return nil
    end

    return self.connection
end

function DatabaseService:Connect()
    if is_database_connection_usable(self.connection) then
        Console.Log("[gr_database][service] Reusing existing database connection.")
        return true, self.connection
    end

    if self.connection ~= nil then
        close_database_if_possible(self.connection)
        self.connection = nil
    end

    local database_constructor, database_runtime_type = resolve_database_constructor()

    if database_constructor == nil then
        Console.Log(
            "[gr_database][service] Database runtime is unavailable in this build. Global Database type=%s.",
            tostring(database_runtime_type)
        )
        return false, "database-runtime-unavailable"
    end

    if type(DatabaseEngine) ~= "table" or DatabaseEngine.PostgreSQL == nil then
        Console.Log("[gr_database][service] DatabaseEngine.PostgreSQL is unavailable. Connection skipped.")
        return false, "postgresql-engine-unavailable"
    end

    if type(self.config) ~= "table" then
        Console.Log("[gr_database][service] Missing normalized database config. Connection skipped.")
        return false, "database-config-missing"
    end

    local connection_string_candidates = build_connection_string_candidates(self.config)

    if connection_string_candidates[1] == nil then
        Console.Log("[gr_database][service] No PostgreSQL connection string candidate could be built from the config.")
        return false, "database-config-missing"
    end

    Console.Log(
        "[gr_database][service] Creating PostgreSQL connection with pool_size=%s using Database runtime type=%s.",
        tostring(self.config.pool_size),
        tostring(database_runtime_type)
    )

    local last_error = nil

    for candidate_index, connection_string in ipairs(connection_string_candidates) do
        local function construct_database()
            return database_constructor(
                DatabaseEngine.PostgreSQL,
                connection_string,
                self.config.pool_size
            )
        end

        local is_constructed, database_or_error = pcall(construct_database)

        if not is_constructed then
            last_error = sanitize_database_error(database_or_error, self.config.password) or "database-constructor-failed"
            Console.Log(
                "[gr_database][service] PostgreSQL constructor attempt #%s failed: %s",
                tostring(candidate_index),
                tostring(last_error)
            )
        else
            local database = database_or_error

            if is_database_connection_usable(database) then
                self.connection = database
                Console.Log("[gr_database][service] Database connection created successfully.")
                return true, self.connection
            end

            close_database_if_possible(database)
            last_error = "database-connection-failed"
            Console.Log(
                "[gr_database][service] PostgreSQL constructor attempt #%s returned an unusable Database entity.",
                tostring(candidate_index)
            )
        end
    end

    return false, normalize_connection_error(last_error)
end

function DatabaseService:RunPlayersSmokeTest()
    if not is_database_connection_usable(self.connection) then
        self.connection = nil
        return false, "database-not-connected"
    end

    self.connection:SelectAsync(SELECT_PLAYERS_SMOKE_TEST_QUERY, function(rows, error)
        if error ~= nil then
            local safe_error = sanitize_database_error(tostring(error), self.config.password)

            Console.Log(
                "[gr_database][server] PostgreSQL optional players smoke test failed: %s",
                tostring(safe_error or "players-smoke-test-failed")
            )

            return
        end

        if type(rows) ~= "table" or rows[1] == nil then
            Console.Log("[gr_database][server] PostgreSQL optional players smoke test OK. No rows found in players.")
            return
        end

        local first_row = rows[1]

        Console.Log(
            "[gr_database][server] PostgreSQL optional players smoke test OK. First row id=%s platform_id=%s username=%s.",
            tostring(first_row.id),
            tostring(first_row.platform_id),
            tostring(first_row.username)
        )
    end)

    return true
end

function DatabaseService:RunSmokeTests()
    if not is_database_connection_usable(self.connection) then
        self.connection = nil
        return false, "database-not-connected"
    end

    self.connection:SelectAsync(SELECT_ONE_SMOKE_TEST_QUERY, function(rows, error)
        if error ~= nil then
            local safe_error = sanitize_database_error(tostring(error), self.config.password)

            Console.Log(
                "[gr_database][server] PostgreSQL smoke test SELECT 1 failed: %s",
                tostring(safe_error or "select-one-smoke-test-failed")
            )
            Console.Log("[gr_database][server] Server continues with database connection available but smoke test failed.")
            return
        end

        local smoke_test_value = nil

        if type(rows) == "table" and rows[1] ~= nil then
            smoke_test_value = rows[1].smoke_test
        end

        Console.Log(
            "[gr_database][server] PostgreSQL smoke test SELECT 1 OK. Result=%s.",
            tostring(smoke_test_value)
        )

        self:RunPlayersSmokeTest()
    end)

    return true
end

function DatabaseService:ConnectAndRunSmokeTests()
    local is_connected, database_or_error = self:Connect()

    if not is_connected then
        local safe_error = normalize_connection_error(
            sanitize_database_error(database_or_error, self.config and self.config.password) or database_or_error
        )

        Console.Log(
            "[gr_database][server] PostgreSQL connection failed: %s",
            tostring(safe_error)
        )
        Console.Log("[gr_database][server] Server continues without database connection.")

        return false, safe_error
    end

    Console.Log("[gr_database][server] PostgreSQL connection successful.")

    local is_started, smoke_test_error = self:RunSmokeTests()

    if not is_started then
        Console.Log(
            "[gr_database][server] PostgreSQL smoke tests could not start: %s",
            tostring(smoke_test_error)
        )

        return false, smoke_test_error
    end

    return true, database_or_error
end

function DatabaseService:Disconnect()
    if self.connection == nil then
        return false
    end

    close_database_if_possible(self.connection)
    self.connection = nil

    Console.Log("[gr_database][service] Database connection closed.")

    return true
end

GRDatabase.Server.DatabaseServiceClass = DatabaseService

return DatabaseService

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

function DatabaseService.Create(config)
    local self = setmetatable({}, DatabaseService)

    self.config = config
    self.connection = nil

    return self
end

function DatabaseService:IsConnected()
    return self.connection ~= nil
end

function DatabaseService:GetConnection()
    return self.connection
end

local function normalize_connection_error(error)
    if type(error) ~= "string" or error == "" then
        return "database-connection-failed"
    end

    return error
end

function DatabaseService:Connect()
    if self.connection ~= nil then
        Console.Log("[gr_database][service] Reusing existing database connection.")
        return true, self.connection
    end

    if type(Database) ~= "function" then
        Console.Log("[gr_database][service] Database runtime is unavailable. Connection skipped.")
        return false, "database-runtime-unavailable"
    end

    if type(DatabaseEngine) ~= "table" or DatabaseEngine.PostgreSQL == nil then
        Console.Log("[gr_database][service] DatabaseEngine.PostgreSQL is unavailable. Connection skipped.")
        return false, "postgresql-engine-unavailable"
    end

    if self.config == nil or self.config.connection_string == nil then
        Console.Log("[gr_database][service] Missing normalized database config. Connection skipped.")
        return false, "database-config-missing"
    end

    Console.Log(
        "[gr_database][service] Creating PostgreSQL connection with pool_size=%s.",
        tostring(self.config.pool_size)
    )

    -- Future repository code will call this service. The nanos world Database
    -- class is intentionally instantiated only on demand, never at package load.
    local database = Database(
        DatabaseEngine.PostgreSQL,
        self.config.connection_string,
        self.config.pool_size
    )

    if database == nil then
        Console.Log("[gr_database][service] Database connection failed or PostgreSQL is not reachable.")
        return false, "database-connection-failed"
    end

    self.connection = database

    Console.Log("[gr_database][service] Database connection created successfully.")

    return true, self.connection
end

function DatabaseService:RunPlayersSmokeTest()
    if self.connection == nil then
        return false, "database-not-connected"
    end

    self.connection:SelectAsync(SELECT_PLAYERS_SMOKE_TEST_QUERY, function(rows, error)
        if error ~= nil then
            Console.Log(
                "[gr_database][server] PostgreSQL optional players smoke test failed: %s",
                tostring(error)
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
    if self.connection == nil then
        return false, "database-not-connected"
    end

    self.connection:SelectAsync(SELECT_ONE_SMOKE_TEST_QUERY, function(rows, error)
        if error ~= nil then
            Console.Log(
                "[gr_database][server] PostgreSQL smoke test SELECT 1 failed: %s",
                tostring(error)
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
        local safe_error = normalize_connection_error(database_or_error)

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

    self.connection:Close()
    self.connection = nil

    Console.Log("[gr_database][service] Database connection closed.")

    return true
end

GRDatabase.Server.DatabaseServiceClass = DatabaseService

return DatabaseService

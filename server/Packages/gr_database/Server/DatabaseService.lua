GRDatabase = GRDatabase or {}
GRDatabase.Server = GRDatabase.Server or {}

local DatabaseService = {}
DatabaseService.__index = DatabaseService

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

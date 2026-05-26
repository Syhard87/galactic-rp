GRDatabase = GRDatabase or {}
GRDatabase.Server = GRDatabase.Server or {}

local DatabaseConfig = {}

local DEFAULTS = {
    engine = "postgresql",
    host = "127.0.0.1",
    port = 5432,
    dbname = "galactic_rp",
    user = "galactic",
    password = nil,
    connect_timeout = 3,
    pool_size = 4,
    auto_connect = false,
    source_label = "safe-defaults",
}

local function copy_table(source)
    local destination = {}

    for key, value in pairs(source) do
        destination[key] = value
    end

    return destination
end

local function normalize_optional_string(value)
    if type(value) ~= "string" then
        return nil
    end

    if value == "" then
        return nil
    end

    return value
end

local function normalize_positive_integer(value, fallback)
    if type(value) ~= "number" then
        return fallback
    end

    local integer_value = math.floor(value)

    if integer_value <= 0 then
        return fallback
    end

    return integer_value
end

function DatabaseConfig.BuildConnectionString(config)
    local connection_parts = {
        "host=" .. config.host,
        "port=" .. tostring(config.port),
        "dbname=" .. config.dbname,
        "user=" .. config.user,
        "connect_timeout=" .. tostring(config.connect_timeout),
    }

    if config.password ~= nil then
        table.insert(connection_parts, "password=" .. config.password)
    end

    return table.concat(connection_parts, " ")
end

function DatabaseConfig.Read(raw_config)
    -- This bootstrap does not parse a real .env file and does not hardcode any
    -- password. A future infra bridge can inject external configuration here.
    local source = raw_config

    if type(source) ~= "table" then
        source = {}
    end

    local config = copy_table(DEFAULTS)

    config.engine = normalize_optional_string(source.engine) or config.engine
    config.host = normalize_optional_string(source.host) or config.host
    config.port = normalize_positive_integer(source.port, config.port)
    config.dbname = normalize_optional_string(source.dbname) or config.dbname
    config.user = normalize_optional_string(source.user) or config.user
    config.password = normalize_optional_string(source.password)
    config.connect_timeout = normalize_positive_integer(source.connect_timeout, config.connect_timeout)
    config.pool_size = normalize_positive_integer(source.pool_size, config.pool_size)
    config.auto_connect = source.auto_connect == true
    config.source_label = normalize_optional_string(source.source_label) or config.source_label
    config.connection_string = DatabaseConfig.BuildConnectionString(config)

    return config
end

function DatabaseConfig.LogSummary(config)
    local has_password = config.password ~= nil

    Console.Log(
        "[gr_database][config] Loaded source=%s engine=%s host=%s port=%s dbname=%s user=%s has_password=%s auto_connect=%s",
        config.source_label,
        config.engine,
        config.host,
        tostring(config.port),
        config.dbname,
        config.user,
        tostring(has_password),
        tostring(config.auto_connect)
    )
end

GRDatabase.Server.DatabaseConfig = DatabaseConfig

return DatabaseConfig

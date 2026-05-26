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

local function normalize_optional_string(value)
    return trim_string(value)
end

local function normalize_positive_integer(value, fallback)
    local numeric_value = value

    if type(numeric_value) == "string" then
        numeric_value = tonumber(trim_string(numeric_value))
    end

    if type(numeric_value) ~= "number" then
        return fallback
    end

    local integer_value = math.floor(numeric_value)

    if integer_value <= 0 then
        return fallback
    end

    return integer_value
end

local function normalize_boolean(value, fallback)
    if type(value) == "boolean" then
        return value
    end

    local string_value = trim_string(value)

    if string_value == nil then
        return fallback
    end

    local lowered_value = string.lower(string_value)

    if lowered_value == "true" or lowered_value == "1" or lowered_value == "yes" or lowered_value == "on" then
        return true
    end

    if lowered_value == "false" or lowered_value == "0" or lowered_value == "no" or lowered_value == "off" then
        return false
    end

    return fallback
end

local function read_server_custom_settings()
    if type(Server) ~= "table" or type(Server.GetCustomSettings) ~= "function" then
        return {}
    end

    local custom_settings = Server.GetCustomSettings()

    if type(custom_settings) ~= "table" then
        return {}
    end

    return custom_settings
end

local function has_custom_database_settings(custom_settings)
    if type(custom_settings) ~= "table" then
        return false
    end

    return custom_settings.gr_database_host ~= nil
        or custom_settings.gr_database_port ~= nil
        or custom_settings.gr_database_name ~= nil
        or custom_settings.gr_database_user ~= nil
        or custom_settings.gr_database_password ~= nil
        or custom_settings.gr_database_auto_connect ~= nil
end

local function map_custom_settings_to_source(custom_settings)
    if not has_custom_database_settings(custom_settings) then
        return nil
    end

    return {
        host = custom_settings.gr_database_host,
        port = custom_settings.gr_database_port,
        dbname = custom_settings.gr_database_name,
        user = custom_settings.gr_database_user,
        password = custom_settings.gr_database_password,
        auto_connect = custom_settings.gr_database_auto_connect,
        source_label = "custom-settings",
    }
end

local function merge_table(destination, source)
    if type(destination) ~= "table" or type(source) ~= "table" then
        return destination
    end

    for key, value in pairs(source) do
        destination[key] = value
    end

    return destination
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
    -- Read runtime custom settings from nanos world first, then allow an
    -- explicit table argument to override or extend that source when needed.
    local source = map_custom_settings_to_source(read_server_custom_settings()) or {}

    if type(raw_config) == "table" then
        source = merge_table(source, raw_config)
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
    config.auto_connect = normalize_boolean(source.auto_connect, config.auto_connect)
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

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

    local normalized_value = value:match("^%s*(.-)%s*$")

    if normalized_value == "" then
        return nil
    end

    return normalized_value
end

local function normalize_positive_integer(value, fallback)
    local numeric_value = value

    if type(numeric_value) == "string" then
        numeric_value = tonumber(normalize_optional_string(numeric_value))
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

    local string_value = normalize_optional_string(value)

    if string_value ~= nil then
        local lowered_value = string.lower(string_value)

        if lowered_value == "true" then
            return true
        end

        if lowered_value == "false" then
            return false
        end
    end

    return fallback
end

local function read_custom_settings()
    if type(Server) ~= "table" and type(Server) ~= "userdata" then
        return nil
    end

    if type(Server.GetCustomSettings) ~= "function" then
        return nil
    end

    local is_read, custom_settings = pcall(Server.GetCustomSettings)

    if not is_read or type(custom_settings) ~= "table" then
        return nil
    end

    return custom_settings
end

local function has_gr_database_settings(source)
    return source.gr_database_host ~= nil
        or source.gr_database_port ~= nil
        or source.gr_database_name ~= nil
        or source.gr_database_user ~= nil
        or source.gr_database_password ~= nil
        or source.gr_database_auto_connect ~= nil
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
    local source = raw_config

    if source == nil then
        source = read_custom_settings()
    end

    if type(source) ~= "table" then
        source = {}
    end

    local config = copy_table(DEFAULTS)
    local has_custom_settings = has_gr_database_settings(source)

    config.engine = normalize_optional_string(source.engine) or config.engine
    config.host = normalize_optional_string(source.gr_database_host) or normalize_optional_string(source.host) or config.host
    config.port = normalize_positive_integer(source.gr_database_port, normalize_positive_integer(source.port, config.port))
    config.dbname = normalize_optional_string(source.gr_database_name) or normalize_optional_string(source.dbname) or config.dbname
    config.user = normalize_optional_string(source.gr_database_user) or normalize_optional_string(source.user) or config.user
    config.password = normalize_optional_string(source.gr_database_password) or normalize_optional_string(source.password)
    config.connect_timeout = normalize_positive_integer(source.connect_timeout, config.connect_timeout)
    config.pool_size = normalize_positive_integer(source.pool_size, config.pool_size)
    config.auto_connect = normalize_boolean(
        source.gr_database_auto_connect,
        normalize_boolean(source.auto_connect, config.auto_connect)
    )
    config.source_label = normalize_optional_string(source.source_label) or config.source_label

    if has_custom_settings then
        config.source_label = "custom-settings"
    end

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

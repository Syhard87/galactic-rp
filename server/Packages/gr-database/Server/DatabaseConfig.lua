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

local CUSTOM_SETTING_KEYS = {
    host = "gr_database_host",
    port = "gr_database_port",
    dbname = "gr_database_name",
    user = "gr_database_user",
    password = "gr_database_password",
    auto_connect = "gr_database_auto_connect",
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

    local trimmed_value = string.gsub(value, "^%s*(.-)%s*$", "%1")

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

    if type(value) == "number" then
        if value == 1 then
            return true
        end

        if value == 0 then
            return false
        end
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

local function resolve_setting_value(source, custom_key, legacy_key)
    if source[custom_key] ~= nil then
        return source[custom_key]
    end

    return source[legacy_key]
end

local function has_custom_database_settings(source)
    for _, custom_key in pairs(CUSTOM_SETTING_KEYS) do
        if source[custom_key] ~= nil then
            return true
        end
    end

    return false
end

local function read_server_custom_settings()
    if type(Server) ~= "table" or type(Server.GetCustomSettings) ~= "function" then
        return {}, DEFAULTS.source_label
    end

    local custom_settings = Server.GetCustomSettings()

    if type(custom_settings) ~= "table" then
        return {}, DEFAULTS.source_label
    end

    if has_custom_database_settings(custom_settings) then
        return custom_settings, "custom-settings"
    end

    return custom_settings, DEFAULTS.source_label
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
    local source_label = nil

    if type(source) ~= "table" then
        source, source_label = read_server_custom_settings()
    end

    local config = copy_table(DEFAULTS)

    config.engine = normalize_optional_string(source.engine) or config.engine
    config.host = normalize_optional_string(resolve_setting_value(source, CUSTOM_SETTING_KEYS.host, "host")) or config.host
    config.port = normalize_positive_integer(resolve_setting_value(source, CUSTOM_SETTING_KEYS.port, "port"), config.port)
    config.dbname = normalize_optional_string(resolve_setting_value(source, CUSTOM_SETTING_KEYS.dbname, "dbname")) or config.dbname
    config.user = normalize_optional_string(resolve_setting_value(source, CUSTOM_SETTING_KEYS.user, "user")) or config.user
    config.password = normalize_optional_string(resolve_setting_value(source, CUSTOM_SETTING_KEYS.password, "password"))
    config.connect_timeout = normalize_positive_integer(source.connect_timeout, config.connect_timeout)
    config.pool_size = normalize_positive_integer(source.pool_size, config.pool_size)
    config.auto_connect = normalize_boolean(
        resolve_setting_value(source, CUSTOM_SETTING_KEYS.auto_connect, "auto_connect"),
        config.auto_connect
    )
    config.source_label = normalize_optional_string(source.source_label) or source_label or config.source_label
    config.connection_string = DatabaseConfig.BuildConnectionString(config)

    return config
end

function DatabaseConfig.LogSummary(config)
    local has_password = config.password ~= nil

    Console.Log(
        "[gr_database][config] Loaded source=%s engine=%s host=%s port=%s database=%s user=%s has_password=%s auto_connect=%s",
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

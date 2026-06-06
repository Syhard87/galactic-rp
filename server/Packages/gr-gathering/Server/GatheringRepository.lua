GRGathering = GRGathering or {}
GRGathering.Server = GRGathering.Server or {}

local GatheringRepository = {}
GatheringRepository.__index = GatheringRepository

local SELECT_NODES_QUERY = [[
    SELECT
        id,
        key,
        name,
        description,
        node_type,
        result_item_key,
        min_quantity,
        max_quantity,
        required_skill_key,
        required_item_key,
        required_item_quantity,
        required_skill_level,
        skill_xp,
        cooldown_seconds,
        position_x,
        position_y,
        position_z,
        radius,
        requires_proximity,
        is_active,
        created_at,
        updated_at
    FROM gathering_nodes
    ORDER BY key ASC, id ASC
]]

local SELECT_NODE_QUERY = [[
    SELECT
        id,
        key,
        name,
        description,
        node_type,
        result_item_key,
        min_quantity,
        max_quantity,
        required_skill_key,
        required_item_key,
        required_item_quantity,
        required_skill_level,
        skill_xp,
        cooldown_seconds,
        position_x,
        position_y,
        position_z,
        radius,
        requires_proximity,
        is_active,
        created_at,
        updated_at
    FROM gathering_nodes
    WHERE key = :0
    LIMIT 1
]]

local SELECT_COOLDOWN_QUERY = [[
    SELECT
        character_id,
        node_key,
        last_gathered_at,
        EXTRACT(EPOCH FROM last_gathered_at) AS last_gathered_epoch,
        gather_count,
        updated_at
    FROM character_gathering_cooldowns
    WHERE character_id = :0
        AND node_key = :1
    LIMIT 1
]]

local UPSERT_COOLDOWN_QUERY = [[
    INSERT INTO character_gathering_cooldowns (
        character_id,
        node_key,
        last_gathered_at,
        gather_count,
        updated_at
    )
    VALUES (
        :0,
        :1,
        NOW(),
        1,
        NOW()
    )
    ON CONFLICT (character_id, node_key) DO UPDATE
    SET
        last_gathered_at = NOW(),
        gather_count = character_gathering_cooldowns.gather_count + 1,
        updated_at = NOW()
    RETURNING
        character_id,
        node_key,
        last_gathered_at,
        EXTRACT(EPOCH FROM last_gathered_at) AS last_gathered_epoch,
        gather_count,
        updated_at
]]

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

local function normalize_positive_integer(value)
    if type(value) == "number" then
        if value < 1 or value % 1 ~= 0 then
            return nil
        end

        return math.floor(value)
    end

    if type(value) == "string" and value:match("^%d+$") ~= nil then
        local parsed_value = tonumber(value)

        if parsed_value ~= nil and parsed_value >= 1 then
            return math.floor(parsed_value)
        end
    end

    return nil
end

local function normalize_non_negative_integer(value)
    if type(value) == "number" then
        if value < 0 or value % 1 ~= 0 then
            return nil
        end

        return math.floor(value)
    end

    if type(value) == "string" and value:match("^%d+$") ~= nil then
        local parsed_value = tonumber(value)

        if parsed_value ~= nil then
            return math.floor(parsed_value)
        end
    end

    return nil
end

local function normalize_boolean(value, fallback)
    if type(value) == "boolean" then
        return value
    end

    local string_value = trim_string(value)

    if string_value ~= nil then
        local lowered_value = string.lower(string_value)

        if lowered_value == "true" or lowered_value == "t" or lowered_value == "1" then
            return true
        end

        if lowered_value == "false" or lowered_value == "f" or lowered_value == "0" then
            return false
        end
    end

    return fallback
end

local function normalize_number(value)
    if type(value) == "number" then
        return value
    end

    if type(value) == "string" then
        local trimmed_value = trim_string(value)

        if trimmed_value == nil then
            return nil
        end

        return tonumber(trimmed_value)
    end

    return nil
end

local function normalize_positive_number(value)
    local normalized_value = normalize_number(value)

    if normalized_value == nil or normalized_value <= 0 then
        return nil
    end

    return normalized_value
end

local function normalize_node_key(node_key)
    return trim_string(node_key)
end

local function normalize_item_key(item_key)
    return trim_string(item_key)
end

local function normalize_skill_key(skill_key)
    local normalized_skill_key = trim_string(skill_key)

    if normalized_skill_key == nil then
        return nil
    end

    normalized_skill_key = string.lower(normalized_skill_key)

    if normalized_skill_key:match("^[a-z0-9_]+$") == nil then
        return nil
    end

    return normalized_skill_key
end

local function normalize_node_row(row)
    local node_id = nil
    local node_key = nil

    if type(row) ~= "table" then
        return nil
    end

    node_id = normalize_positive_integer(row.id)
    node_key = normalize_node_key(row.key)

    if node_id == nil or node_key == nil then
        return nil
    end

    return {
        id = node_id,
        key = node_key,
        name = trim_string(row.name),
        description = trim_string(row.description),
        node_type = trim_string(row.node_type),
        result_item_key = normalize_item_key(row.result_item_key),
        min_quantity = normalize_positive_integer(row.min_quantity),
        max_quantity = normalize_positive_integer(row.max_quantity),
        required_skill_key = normalize_skill_key(row.required_skill_key),
        required_item_key = normalize_item_key(row.required_item_key),
        required_item_quantity = normalize_positive_integer(row.required_item_quantity) or 1,
        required_skill_level = normalize_positive_integer(row.required_skill_level),
        skill_xp = normalize_non_negative_integer(row.skill_xp) or 0,
        cooldown_seconds = normalize_positive_integer(row.cooldown_seconds),
        position_x = normalize_number(row.position_x),
        position_y = normalize_number(row.position_y),
        position_z = normalize_number(row.position_z),
        radius = normalize_positive_number(row.radius),
        requires_proximity = normalize_boolean(row.requires_proximity, false),
        is_active = normalize_boolean(row.is_active, false),
        created_at = row.created_at,
        updated_at = row.updated_at,
    }
end

local function normalize_cooldown_row(row)
    local character_id = nil
    local node_key = nil

    if type(row) ~= "table" then
        return nil
    end

    character_id = normalize_positive_integer(row.character_id)
    node_key = normalize_node_key(row.node_key)

    if character_id == nil or node_key == nil then
        return nil
    end

    return {
        character_id = character_id,
        node_key = node_key,
        last_gathered_at = row.last_gathered_at,
        last_gathered_epoch = tonumber(row.last_gathered_epoch) or 0,
        gather_count = normalize_non_negative_integer(row.gather_count) or 0,
        updated_at = row.updated_at,
    }
end

local function normalize_rows(rows, normalizer)
    local normalized_rows = {}

    for _, row in ipairs(rows or {}) do
        local normalized_row = normalizer(row)

        if normalized_row ~= nil then
            normalized_rows[#normalized_rows + 1] = normalized_row
        end
    end

    return normalized_rows
end

function GatheringRepository.Create(database_service)
    local self = setmetatable({}, GatheringRepository)

    self.database_service = database_service

    return self
end

function GatheringRepository:Connect(callback, reason)
    local is_connected = false
    local database_or_error = nil

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if self.database_service == nil then
        Console.Log(
            "[gr_gathering][repository] Database service unavailable during %s.",
            tostring(reason or "gathering-call")
        )
        callback(false, nil, "database-service-missing")
        return true
    end

    is_connected, database_or_error = self.database_service:Connect()

    if not is_connected then
        Console.Log(
            "[gr_gathering][repository] Database connection failed during %s with error=%s.",
            tostring(reason or "gathering-call"),
            tostring(database_or_error)
        )
        callback(false, nil, database_or_error)
        return true
    end

    callback(true, database_or_error, nil)
    return true
end

function GatheringRepository:ListNodes(callback)
    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    return self:Connect(function(is_connected, database_or_error, error)
        if not is_connected then
            callback(false, nil, error)
            return
        end

        database_or_error:SelectAsync(SELECT_NODES_QUERY, function(rows, select_error)
            if select_error ~= nil then
                callback(false, nil, select_error)
                return
            end

            callback(true, normalize_rows(rows, normalize_node_row), nil)
        end)
    end, "nodes-list")
end

function GatheringRepository:GetNode(node_key, callback)
    local normalized_node_key = normalize_node_key(node_key)

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if normalized_node_key == nil then
        callback(false, nil, "node-key-required")
        return true
    end

    return self:Connect(function(is_connected, database_or_error, error)
        if not is_connected then
            callback(false, nil, error)
            return
        end

        database_or_error:SelectAsync(SELECT_NODE_QUERY, function(rows, select_error)
            local normalized_rows = nil

            if select_error ~= nil then
                callback(false, nil, select_error)
                return
            end

            normalized_rows = normalize_rows(rows, normalize_node_row)
            callback(true, normalized_rows[1], nil)
        end, normalized_node_key)
    end, "node-get")
end

function GatheringRepository:GetCooldown(character_id, node_key, callback)
    local normalized_character_id = normalize_positive_integer(character_id)
    local normalized_node_key = normalize_node_key(node_key)

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if normalized_character_id == nil then
        callback(false, nil, "character-id-required")
        return true
    end

    if normalized_node_key == nil then
        callback(false, nil, "node-key-required")
        return true
    end

    return self:Connect(function(is_connected, database_or_error, error)
        if not is_connected then
            callback(false, nil, error)
            return
        end

        database_or_error:SelectAsync(SELECT_COOLDOWN_QUERY, function(rows, select_error)
            local normalized_rows = nil

            if select_error ~= nil then
                callback(false, nil, select_error)
                return
            end

            normalized_rows = normalize_rows(rows, normalize_cooldown_row)
            callback(true, normalized_rows[1], nil)
        end, normalized_character_id, normalized_node_key)
    end, "gathering-cooldown-get")
end

function GatheringRepository:UpsertCooldown(character_id, node_key, callback)
    local normalized_character_id = normalize_positive_integer(character_id)
    local normalized_node_key = normalize_node_key(node_key)

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if normalized_character_id == nil then
        callback(false, nil, "character-id-required")
        return true
    end

    if normalized_node_key == nil then
        callback(false, nil, "node-key-required")
        return true
    end

    return self:Connect(function(is_connected, database_or_error, error)
        if not is_connected then
            callback(false, nil, error)
            return
        end

        database_or_error:SelectAsync(UPSERT_COOLDOWN_QUERY, function(rows, select_error)
            local normalized_rows = nil

            if select_error ~= nil then
                callback(false, nil, select_error)
                return
            end

            normalized_rows = normalize_rows(rows, normalize_cooldown_row)
            callback(true, normalized_rows[1], nil)
        end, normalized_character_id, normalized_node_key)
    end, "gathering-cooldown-upsert")
end

GRGathering.Server.GatheringRepositoryClass = GatheringRepository

return GatheringRepository

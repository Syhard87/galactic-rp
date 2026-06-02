GRReputation = GRReputation or {}
GRReputation.Server = GRReputation.Server or {}

local ReputationRepository = {}
ReputationRepository.__index = ReputationRepository

local SELECT_DEFINITIONS_QUERY = [[
    SELECT
        key,
        name,
        description,
        min_value,
        max_value,
        default_value,
        is_active,
        created_at,
        updated_at
    FROM reputation_definitions
    ORDER BY key ASC
]]

local SELECT_DEFINITION_BY_KEY_QUERY = [[
    SELECT
        key,
        name,
        description,
        min_value,
        max_value,
        default_value,
        is_active,
        created_at,
        updated_at
    FROM reputation_definitions
    WHERE key = :0
    LIMIT 1
]]

local SELECT_CHARACTER_REPUTATIONS_QUERY = [[
    SELECT
        id,
        character_id,
        reputation_key,
        value,
        rank,
        updated_at,
        created_at
    FROM character_reputations
    WHERE character_id = :0
    ORDER BY reputation_key ASC
]]

local SELECT_CHARACTER_REPUTATION_QUERY = [[
    SELECT
        id,
        character_id,
        reputation_key,
        value,
        rank,
        updated_at,
        created_at
    FROM character_reputations
    WHERE character_id = :0 AND reputation_key = :1
    LIMIT 1
]]

local UPSERT_CHARACTER_REPUTATION_QUERY = [[
    INSERT INTO character_reputations (
        character_id,
        reputation_key,
        value,
        rank
    )
    VALUES (
        :0,
        :1,
        :2,
        :3
    )
    ON CONFLICT (character_id, reputation_key) DO UPDATE
    SET
        value = EXCLUDED.value,
        rank = EXCLUDED.rank,
        updated_at = NOW()
    RETURNING
        id,
        character_id,
        reputation_key,
        value,
        rank,
        updated_at,
        created_at
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

local function normalize_integer(value, fallback)
    if type(value) == "number" then
        if value % 1 ~= 0 then
            return fallback
        end

        return math.floor(value)
    end

    if type(value) == "string" and value:match("^[+-]?%d+$") ~= nil then
        local parsed_value = tonumber(value)

        if parsed_value ~= nil then
            return math.floor(parsed_value)
        end
    end

    return fallback
end

local function normalize_reputation_key(reputation_key)
    local normalized_reputation_key = trim_string(reputation_key)

    if normalized_reputation_key == nil then
        return nil
    end

    normalized_reputation_key = string.lower(normalized_reputation_key)

    if normalized_reputation_key:match("^[a-z0-9_]+$") == nil then
        return nil
    end

    return normalized_reputation_key
end

local function normalize_rank(rank)
    local normalized_rank = trim_string(rank)

    if normalized_rank == nil then
        return "neutral"
    end

    return string.lower(normalized_rank)
end

local function normalize_definition_row(row)
    local reputation_key = nil

    if type(row) ~= "table" then
        return nil
    end

    reputation_key = normalize_reputation_key(row.key)

    if reputation_key == nil then
        return nil
    end

    return {
        key = reputation_key,
        name = trim_string(row.name) or reputation_key,
        description = trim_string(row.description),
        min_value = normalize_integer(row.min_value, -1000),
        max_value = normalize_integer(row.max_value, 1000),
        default_value = normalize_integer(row.default_value, 0),
        is_active = row.is_active == true,
        created_at = row.created_at,
        updated_at = row.updated_at,
    }
end

local function normalize_character_reputation_row(row)
    local reputation_id = nil
    local character_id = nil
    local reputation_key = nil

    if type(row) ~= "table" then
        return nil
    end

    reputation_id = normalize_positive_integer(row.id)
    character_id = normalize_positive_integer(row.character_id)
    reputation_key = normalize_reputation_key(row.reputation_key)

    if reputation_id == nil or character_id == nil or reputation_key == nil then
        return nil
    end

    return {
        id = reputation_id,
        character_id = character_id,
        reputation_key = reputation_key,
        value = normalize_integer(row.value, 0),
        rank = normalize_rank(row.rank),
        updated_at = row.updated_at,
        created_at = row.created_at,
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

function ReputationRepository.Create(database_service)
    local self = setmetatable({}, ReputationRepository)

    self.database_service = database_service

    return self
end

function ReputationRepository:Connect(callback, reason)
    local is_connected = false
    local database_or_error = nil

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if self.database_service == nil then
        Console.Log(
            "[gr_reputation][repository] Database service unavailable during %s.",
            tostring(reason or "reputation-call")
        )
        callback(false, nil, "database-service-missing")
        return true
    end

    is_connected, database_or_error = self.database_service:Connect()

    if not is_connected then
        Console.Log(
            "[gr_reputation][repository] Database connection failed during %s with error=%s.",
            tostring(reason or "reputation-call"),
            tostring(database_or_error)
        )
        callback(false, nil, database_or_error)
        return true
    end

    callback(true, database_or_error, nil)
    return true
end

function ReputationRepository:ListDefinitions(callback)
    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    return self:Connect(function(is_connected, database_or_error, error)
        if not is_connected then
            callback(false, nil, error)
            return
        end

        database_or_error:SelectAsync(SELECT_DEFINITIONS_QUERY, function(rows, select_error)
            local definition_rows = nil

            if select_error ~= nil then
                callback(false, nil, select_error)
                return
            end

            definition_rows = normalize_rows(rows, normalize_definition_row)

            Console.Log(
                "[gr_reputation][repository] Reputation definitions loaded count=%s.",
                tostring(#definition_rows)
            )

            callback(true, definition_rows, nil)
        end)
    end, "reputation-list-definitions")
end

function ReputationRepository:GetDefinition(reputation_key, callback)
    local normalized_reputation_key = normalize_reputation_key(reputation_key)

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if normalized_reputation_key == nil then
        callback(false, nil, "reputation-key-required")
        return true
    end

    return self:Connect(function(is_connected, database_or_error, error)
        if not is_connected then
            callback(false, nil, error)
            return
        end

        database_or_error:SelectAsync(SELECT_DEFINITION_BY_KEY_QUERY, function(rows, select_error)
            local definition_rows = nil
            local definition_row = nil

            if select_error ~= nil then
                callback(false, nil, select_error)
                return
            end

            definition_rows = normalize_rows(rows, normalize_definition_row)
            definition_row = definition_rows[1]

            callback(true, definition_row, nil)
        end, normalized_reputation_key)
    end, "reputation-get-definition")
end

function ReputationRepository:ListCharacterReputations(character_id, callback)
    local normalized_character_id = normalize_positive_integer(character_id)

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if normalized_character_id == nil then
        callback(false, nil, "character-id-required")
        return true
    end

    return self:Connect(function(is_connected, database_or_error, error)
        if not is_connected then
            callback(false, nil, error)
            return
        end

        database_or_error:SelectAsync(SELECT_CHARACTER_REPUTATIONS_QUERY, function(rows, select_error)
            local reputation_rows = nil

            if select_error ~= nil then
                callback(false, nil, select_error)
                return
            end

            reputation_rows = normalize_rows(rows, normalize_character_reputation_row)
            callback(true, reputation_rows, nil)
        end, normalized_character_id)
    end, "reputation-list-character")
end

function ReputationRepository:GetCharacterReputation(character_id, reputation_key, callback)
    local normalized_character_id = normalize_positive_integer(character_id)
    local normalized_reputation_key = normalize_reputation_key(reputation_key)

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if normalized_character_id == nil then
        callback(false, nil, "character-id-required")
        return true
    end

    if normalized_reputation_key == nil then
        callback(false, nil, "reputation-key-required")
        return true
    end

    return self:Connect(function(is_connected, database_or_error, error)
        if not is_connected then
            callback(false, nil, error)
            return
        end

        database_or_error:SelectAsync(SELECT_CHARACTER_REPUTATION_QUERY, function(rows, select_error)
            local reputation_rows = nil

            if select_error ~= nil then
                callback(false, nil, select_error)
                return
            end

            reputation_rows = normalize_rows(rows, normalize_character_reputation_row)
            callback(true, reputation_rows[1], nil)
        end, normalized_character_id, normalized_reputation_key)
    end, "reputation-get-character")
end

function ReputationRepository:UpsertCharacterReputation(character_id, reputation_key, value, rank, callback)
    local normalized_character_id = normalize_positive_integer(character_id)
    local normalized_reputation_key = normalize_reputation_key(reputation_key)
    local normalized_value = normalize_integer(value, nil)
    local normalized_rank = normalize_rank(rank)

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if normalized_character_id == nil then
        callback(false, nil, "character-id-required")
        return true
    end

    if normalized_reputation_key == nil then
        callback(false, nil, "reputation-key-required")
        return true
    end

    if normalized_value == nil then
        callback(false, nil, "reputation-value-required")
        return true
    end

    return self:Connect(function(is_connected, database_or_error, error)
        if not is_connected then
            callback(false, nil, error)
            return
        end

        database_or_error:SelectAsync(UPSERT_CHARACTER_REPUTATION_QUERY, function(rows, select_error)
            local reputation_rows = nil

            if select_error ~= nil then
                callback(false, nil, select_error)
                return
            end

            reputation_rows = normalize_rows(rows, normalize_character_reputation_row)

            callback(true, reputation_rows[1], nil)
        end,
            normalized_character_id,
            normalized_reputation_key,
            normalized_value,
            normalized_rank
        )
    end, "reputation-upsert-character")
end

GRReputation.Server.ReputationRepositoryClass = ReputationRepository

return ReputationRepository

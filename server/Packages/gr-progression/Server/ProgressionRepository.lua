GRProgression = GRProgression or {}
GRProgression.Server = GRProgression.Server or {}

local ProgressionConfig = GRProgression.Shared and GRProgression.Shared.ProgressionConfig

local ProgressionRepository = {}
ProgressionRepository.__index = ProgressionRepository

local SELECT_BY_CHARACTER_ID_QUERY = [[
    SELECT
        character_id,
        level,
        current_xp,
        total_xp,
        class_key,
        specialization_key,
        unspent_talent_points,
        created_at,
        updated_at
    FROM character_progression
    WHERE character_id = :0
    LIMIT 1
]]

local INSERT_DEFAULT_QUERY = [[
    INSERT INTO character_progression (
        character_id,
        class_key
    )
    VALUES (
        :0,
        :1
    )
    ON CONFLICT (character_id) DO NOTHING
]]

local UPDATE_PROGRESSION_QUERY = [[
    UPDATE character_progression
    SET
        level = :0,
        current_xp = :1,
        total_xp = :2,
        class_key = :3,
        specialization_key = :4,
        unspent_talent_points = :5,
        updated_at = NOW()
    WHERE character_id = :6
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

local function normalize_non_negative_integer(value, fallback)
    if type(value) == "number" then
        if value < 0 then
            return fallback
        end

        return math.floor(value)
    end

    if type(value) == "string" and value:match("^%d+$") ~= nil then
        local parsed_value = tonumber(value)

        if parsed_value ~= nil and parsed_value >= 0 then
            return math.floor(parsed_value)
        end
    end

    return fallback
end

local function normalize_class_key(class_key)
    if type(ProgressionConfig) == "table" and type(ProgressionConfig.NormalizeClassKey) == "function" then
        return ProgressionConfig.NormalizeClassKey(class_key)
    end

    return trim_string(class_key) or "civilian"
end

local function normalize_progression_row(row)
    local character_id = nil

    if type(row) ~= "table" then
        return nil
    end

    character_id = normalize_positive_integer(row.character_id)

    if character_id == nil then
        return nil
    end

    return {
        character_id = character_id,
        level = normalize_positive_integer(row.level) or 1,
        current_xp = normalize_non_negative_integer(row.current_xp, 0),
        total_xp = normalize_non_negative_integer(row.total_xp, 0),
        class_key = normalize_class_key(row.class_key),
        specialization_key = trim_string(row.specialization_key),
        unspent_talent_points = normalize_non_negative_integer(row.unspent_talent_points, 0),
        created_at = row.created_at,
        updated_at = row.updated_at,
    }
end

function ProgressionRepository.Create(database_service)
    local self = setmetatable({}, ProgressionRepository)

    self.database_service = database_service

    return self
end

function ProgressionRepository:Connect(callback, reason)
    local is_connected = false
    local database_or_error = nil

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if self.database_service == nil then
        Console.Log(
            "[gr_progression][repository] Database service unavailable during %s.",
            tostring(reason or "progression-call")
        )
        callback(false, nil, "database-service-missing")
        return true
    end

    is_connected, database_or_error = self.database_service:Connect()

    if not is_connected then
        Console.Log(
            "[gr_progression][repository] Database connection failed during %s with error=%s.",
            tostring(reason or "progression-call"),
            tostring(database_or_error)
        )
        callback(false, nil, database_or_error)
        return true
    end

    callback(true, database_or_error, nil)
    return true
end

function ProgressionRepository:GetByCharacterId(character_id, callback)
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

        database_or_error:SelectAsync(SELECT_BY_CHARACTER_ID_QUERY, function(rows, select_error)
            local progression_row = nil

            if select_error ~= nil then
                Console.Log(
                    "[gr_progression][repository] Progression load failed character_id=%s error=%s.",
                    tostring(normalized_character_id),
                    tostring(select_error)
                )
                callback(false, nil, select_error)
                return
            end

            if type(rows) == "table" and rows[1] ~= nil then
                progression_row = normalize_progression_row(rows[1])
            end

            if progression_row ~= nil then
                Console.Log(
                    "[gr_progression][repository] Progression loaded character_id=%s level=%s.",
                    tostring(progression_row.character_id),
                    tostring(progression_row.level)
                )
            end

            callback(true, progression_row, nil)
        end, normalized_character_id)
    end, "progression-get-by-character-id")
end

function ProgressionRepository:CreateDefault(character_id, class_key, callback)
    local normalized_character_id = normalize_positive_integer(character_id)
    local normalized_class_key = normalize_class_key(class_key)

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

        database_or_error:ExecuteAsync(INSERT_DEFAULT_QUERY, function(_, execute_error)
            if execute_error ~= nil then
                Console.Log(
                    "[gr_progression][repository] Default progression create failed character_id=%s error=%s.",
                    tostring(normalized_character_id),
                    tostring(execute_error)
                )
                callback(false, nil, execute_error)
                return
            end

            Console.Log(
                "[gr_progression][repository] Default progression created character_id=%s class_key=%s.",
                tostring(normalized_character_id),
                tostring(normalized_class_key)
            )

            self:GetByCharacterId(normalized_character_id, callback)
        end, normalized_character_id, normalized_class_key)
    end, "progression-create-default")
end

function ProgressionRepository:GetOrCreate(character_id, class_key, callback)
    local normalized_character_id = normalize_positive_integer(character_id)
    local normalized_class_key = normalize_class_key(class_key)

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if normalized_character_id == nil then
        callback(false, nil, "character-id-required")
        return true
    end

    return self:GetByCharacterId(normalized_character_id, function(is_success, progression_row, error)
        if not is_success then
            callback(false, nil, error)
            return
        end

        if progression_row ~= nil then
            callback(true, progression_row, nil)
            return
        end

        self:CreateDefault(normalized_character_id, normalized_class_key, callback)
    end)
end

function ProgressionRepository:SaveProgression(progression, callback)
    local normalized_progression = normalize_progression_row(progression)

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if normalized_progression == nil then
        callback(false, nil, "progression-required")
        return true
    end

    return self:Connect(function(is_connected, database_or_error, error)
        if not is_connected then
            callback(false, nil, error)
            return
        end

        database_or_error:ExecuteAsync(UPDATE_PROGRESSION_QUERY, function(_, execute_error)
            if execute_error ~= nil then
                Console.Log(
                    "[gr_progression][repository] Progression save failed character_id=%s error=%s.",
                    tostring(normalized_progression.character_id),
                    tostring(execute_error)
                )
                callback(false, nil, execute_error)
                return
            end

            Console.Log(
                "[gr_progression][repository] Progression saved character_id=%s level=%s current_xp=%s total_xp=%s.",
                tostring(normalized_progression.character_id),
                tostring(normalized_progression.level),
                tostring(normalized_progression.current_xp),
                tostring(normalized_progression.total_xp)
            )

            callback(true, normalized_progression, nil)
        end,
            normalized_progression.level,
            normalized_progression.current_xp,
            normalized_progression.total_xp,
            normalized_progression.class_key,
            normalized_progression.specialization_key,
            normalized_progression.unspent_talent_points,
            normalized_progression.character_id
        )
    end, "progression-save")
end

GRProgression.Server.ProgressionRepositoryClass = ProgressionRepository

return ProgressionRepository

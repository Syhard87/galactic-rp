GRQuests = GRQuests or {}
GRQuests.Server = GRQuests.Server or {}

local QuestConfig = GRQuests.Shared and GRQuests.Shared.QuestConfig

local QuestRepository = {}
QuestRepository.__index = QuestRepository

local SELECT_AVAILABLE_QUESTS_QUERY = [[
    SELECT
        key,
        title,
        description,
        reward_xp,
        is_repeatable,
        is_active,
        created_at,
        updated_at
    FROM quests
    WHERE is_active = TRUE
    ORDER BY key ASC
]]

local SELECT_QUEST_BY_KEY_QUERY = [[
    SELECT
        key,
        title,
        description,
        reward_xp,
        is_repeatable,
        is_active,
        created_at,
        updated_at
    FROM quests
    WHERE key = :0
    LIMIT 1
]]

local SELECT_CHARACTER_QUESTS_QUERY = [[
    SELECT
        cq.id,
        cq.character_id,
        cq.quest_key,
        cq.status,
        cq.started_at,
        cq.completed_at,
        cq.created_at,
        cq.updated_at,
        q.title,
        q.reward_xp
    FROM character_quests cq
    INNER JOIN quests q
        ON q.key = cq.quest_key
    WHERE cq.character_id = :0
    ORDER BY cq.started_at DESC, cq.id DESC
]]

local SELECT_STARTED_CHARACTER_QUEST_QUERY = [[
    SELECT
        cq.id,
        cq.character_id,
        cq.quest_key,
        cq.status,
        cq.started_at,
        cq.completed_at,
        cq.created_at,
        cq.updated_at,
        q.title,
        q.reward_xp
    FROM character_quests cq
    INNER JOIN quests q
        ON q.key = cq.quest_key
    WHERE cq.character_id = :0
        AND cq.quest_key = :1
        AND cq.status = 'started'
    ORDER BY cq.id DESC
    LIMIT 1
]]

local INSERT_CHARACTER_QUEST_QUERY = [[
    INSERT INTO character_quests (
        character_id,
        quest_key
    )
    VALUES (
        :0,
        :1
    )
]]

local UPDATE_COMPLETE_CHARACTER_QUEST_QUERY = [[
    UPDATE character_quests
    SET
        status = 'completed',
        completed_at = NOW(),
        updated_at = NOW()
    WHERE id = :0
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

local function normalize_quest_key(quest_key)
    if type(QuestConfig) == "table" and type(QuestConfig.NormalizeQuestKey) == "function" then
        return QuestConfig.NormalizeQuestKey(quest_key)
    end

    return trim_string(quest_key)
end

local function normalize_quest_status(status)
    local normalized_status = trim_string(status)

    if normalized_status == nil then
        return nil
    end

    normalized_status = string.lower(normalized_status)

    if type(QuestConfig) == "table" and type(QuestConfig.IsValidQuestStatus) == "function" then
        if not QuestConfig.IsValidQuestStatus(normalized_status) then
            return nil
        end
    end

    return normalized_status
end

local function normalize_quest_row(row)
    local quest_key = nil

    if type(row) ~= "table" then
        return nil
    end

    quest_key = normalize_quest_key(row.key)

    if quest_key == nil then
        return nil
    end

    return {
        key = quest_key,
        title = trim_string(row.title) or quest_key,
        description = trim_string(row.description),
        reward_xp = normalize_non_negative_integer(row.reward_xp, 0),
        is_repeatable = row.is_repeatable == true,
        is_active = row.is_active ~= false,
        created_at = row.created_at,
        updated_at = row.updated_at,
    }
end

local function normalize_character_quest_row(row)
    local quest_id = nil
    local character_id = nil
    local quest_key = nil
    local status = nil

    if type(row) ~= "table" then
        return nil
    end

    quest_id = normalize_positive_integer(row.id)
    character_id = normalize_positive_integer(row.character_id)
    quest_key = normalize_quest_key(row.quest_key)
    status = normalize_quest_status(row.status)

    if quest_id == nil or character_id == nil or quest_key == nil or status == nil then
        return nil
    end

    return {
        id = quest_id,
        character_id = character_id,
        quest_key = quest_key,
        status = status,
        started_at = row.started_at,
        completed_at = row.completed_at,
        created_at = row.created_at,
        updated_at = row.updated_at,
        title = trim_string(row.title),
        reward_xp = normalize_non_negative_integer(row.reward_xp, 0),
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

function QuestRepository.Create(database_service)
    local self = setmetatable({}, QuestRepository)

    self.database_service = database_service

    return self
end

function QuestRepository:Connect(callback, reason)
    local is_connected = false
    local database_or_error = nil

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if self.database_service == nil then
        Console.Log(
            "[gr_quests][repository] Database service unavailable during %s.",
            tostring(reason or "quest-call")
        )
        callback(false, nil, "database-service-missing")
        return true
    end

    is_connected, database_or_error = self.database_service:Connect()

    if not is_connected then
        Console.Log(
            "[gr_quests][repository] Database connection failed during %s with error=%s.",
            tostring(reason or "quest-call"),
            tostring(database_or_error)
        )
        callback(false, nil, database_or_error)
        return true
    end

    callback(true, database_or_error, nil)
    return true
end

function QuestRepository:GetQuestByKey(quest_key, callback)
    local normalized_quest_key = normalize_quest_key(quest_key)

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if normalized_quest_key == nil then
        callback(false, nil, "quest-key-required")
        return true
    end

    return self:Connect(function(is_connected, database_or_error, error)
        if not is_connected then
            callback(false, nil, error)
            return
        end

        database_or_error:SelectAsync(SELECT_QUEST_BY_KEY_QUERY, function(rows, select_error)
            local quest_row = nil

            if select_error ~= nil then
                callback(false, nil, select_error)
                return
            end

            if type(rows) == "table" and rows[1] ~= nil then
                quest_row = normalize_quest_row(rows[1])
            end

            callback(true, quest_row, nil)
        end, normalized_quest_key)
    end, "quest-get-by-key")
end

function QuestRepository:ListAvailableQuests(callback)
    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    return self:Connect(function(is_connected, database_or_error, error)
        if not is_connected then
            callback(false, nil, error)
            return
        end

        database_or_error:SelectAsync(SELECT_AVAILABLE_QUESTS_QUERY, function(rows, select_error)
            local quests = nil

            if select_error ~= nil then
                callback(false, nil, select_error)
                return
            end

            quests = normalize_rows(rows, normalize_quest_row)

            Console.Log(
                "[gr_quests][repository] Available quests loaded count=%s.",
                tostring(#quests)
            )

            callback(true, quests, nil)
        end)
    end, "quest-list-available")
end

function QuestRepository:ListCharacterQuests(character_id, callback)
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

        database_or_error:SelectAsync(SELECT_CHARACTER_QUESTS_QUERY, function(rows, select_error)
            local character_quests = nil

            if select_error ~= nil then
                callback(false, nil, select_error)
                return
            end

            character_quests = normalize_rows(rows, normalize_character_quest_row)

            Console.Log(
                "[gr_quests][repository] Character quests loaded character_id=%s count=%s.",
                tostring(normalized_character_id),
                tostring(#character_quests)
            )

            callback(true, character_quests, nil)
        end, normalized_character_id)
    end, "quest-list-character")
end

function QuestRepository:StartQuest(character_id, quest_key, callback)
    local normalized_character_id = normalize_positive_integer(character_id)
    local normalized_quest_key = normalize_quest_key(quest_key)

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if normalized_character_id == nil then
        callback(false, nil, "character-id-required")
        return true
    end

    if normalized_quest_key == nil then
        callback(false, nil, "quest-key-required")
        return true
    end

    return self:GetQuestByKey(normalized_quest_key, function(is_quest_success, quest_row, quest_error)
        if not is_quest_success then
            callback(false, nil, quest_error)
            return
        end

        if quest_row == nil or quest_row.is_active ~= true then
            callback(false, nil, "quest-not-found")
            return
        end

        self:Connect(function(is_connected, database_or_error, error)
            if not is_connected then
                callback(false, nil, error)
                return
            end

            database_or_error:SelectAsync(SELECT_STARTED_CHARACTER_QUEST_QUERY, function(rows, select_error)
                local existing_rows = nil

                if select_error ~= nil then
                    callback(false, nil, select_error)
                    return
                end

                existing_rows = normalize_rows(rows, normalize_character_quest_row)

                if existing_rows[1] ~= nil then
                    callback(false, nil, "quest-already-started")
                    return
                end

                database_or_error:ExecuteAsync(INSERT_CHARACTER_QUEST_QUERY, function(_, execute_error)
                    local started_row = nil

                    if execute_error ~= nil then
                        callback(false, nil, execute_error)
                        return
                    end

                    started_row = {
                        id = nil,
                        character_id = normalized_character_id,
                        quest_key = normalized_quest_key,
                        status = "started",
                        title = quest_row.title,
                        reward_xp = quest_row.reward_xp,
                    }

                    Console.Log(
                        "[gr_quests][repository] Quest started character_id=%s quest_key=%s.",
                        tostring(normalized_character_id),
                        tostring(normalized_quest_key)
                    )

                    callback(true, started_row, nil)
                end, normalized_character_id, normalized_quest_key)
            end, normalized_character_id, normalized_quest_key)
        end, "quest-start")
    end)
end

function QuestRepository:CompleteQuest(character_id, quest_key, callback)
    local normalized_character_id = normalize_positive_integer(character_id)
    local normalized_quest_key = normalize_quest_key(quest_key)

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if normalized_character_id == nil then
        callback(false, nil, "character-id-required")
        return true
    end

    if normalized_quest_key == nil then
        callback(false, nil, "quest-key-required")
        return true
    end

    return self:Connect(function(is_connected, database_or_error, error)
        if not is_connected then
            callback(false, nil, error)
            return
        end

        database_or_error:SelectAsync(SELECT_STARTED_CHARACTER_QUEST_QUERY, function(rows, select_error)
            local started_rows = nil
            local started_row = nil

            if select_error ~= nil then
                callback(false, nil, select_error)
                return
            end

            started_rows = normalize_rows(rows, normalize_character_quest_row)
            started_row = started_rows[1]

            if started_row == nil then
                callback(false, nil, "quest-not-started")
                return
            end

            database_or_error:ExecuteAsync(UPDATE_COMPLETE_CHARACTER_QUEST_QUERY, function(_, execute_error)
                if execute_error ~= nil then
                    callback(false, nil, execute_error)
                    return
                end

                started_row.status = "completed"
                started_row.completed_at = os.date("!%Y-%m-%dT%H:%M:%SZ")

                Console.Log(
                    "[gr_quests][repository] Quest completed character_id=%s quest_key=%s.",
                    tostring(normalized_character_id),
                    tostring(normalized_quest_key)
                )

                callback(true, started_row, nil)
            end, started_row.id)
        end, normalized_character_id, normalized_quest_key)
    end, "quest-complete")
end

GRQuests.Server.QuestRepositoryClass = QuestRepository

return QuestRepository

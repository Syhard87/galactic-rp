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
        reward_item_key,
        reward_item_quantity,
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
        reward_item_key,
        reward_item_quantity,
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
        q.reward_xp,
        q.reward_item_key,
        q.reward_item_quantity
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
        q.reward_xp,
        q.reward_item_key,
        q.reward_item_quantity
    FROM character_quests cq
    INNER JOIN quests q
        ON q.key = cq.quest_key
    WHERE cq.character_id = :0
        AND cq.quest_key = :1
        AND cq.status = 'started'
    ORDER BY cq.id DESC
    LIMIT 1
]]

local SELECT_QUEST_OBJECTIVES_QUERY = [[
    SELECT
        quest_key,
        objective_key,
        description,
        target_type,
        target_key,
        required_count,
        order_index,
        created_at,
        updated_at
    FROM quest_objectives
    WHERE quest_key = :0
    ORDER BY order_index ASC, objective_key ASC
]]

local SELECT_CHARACTER_QUEST_OBJECTIVES_QUERY = [[
    SELECT
        cqo.character_quest_id,
        cqo.objective_key,
        cqo.current_count,
        cqo.required_count,
        cqo.completed_at,
        cqo.created_at,
        cqo.updated_at,
        qo.quest_key,
        qo.description,
        qo.target_type,
        qo.target_key,
        qo.order_index
    FROM character_quest_objectives cqo
    INNER JOIN character_quests cq
        ON cq.id = cqo.character_quest_id
    INNER JOIN quest_objectives qo
        ON qo.quest_key = cq.quest_key
        AND qo.objective_key = cqo.objective_key
    WHERE cqo.character_quest_id = :0
    ORDER BY qo.order_index ASC, cqo.objective_key ASC
]]

local SELECT_MATCHING_STARTED_OBJECTIVES_WITH_TARGET_KEY_QUERY = [[
    SELECT
        cqo.character_quest_id,
        cqo.objective_key,
        cqo.current_count,
        cqo.required_count,
        cqo.completed_at,
        cqo.created_at,
        cqo.updated_at,
        qo.quest_key,
        qo.description,
        qo.target_type,
        qo.target_key,
        qo.order_index
    FROM character_quest_objectives cqo
    INNER JOIN character_quests cq
        ON cq.id = cqo.character_quest_id
    INNER JOIN quest_objectives qo
        ON qo.quest_key = cq.quest_key
        AND qo.objective_key = cqo.objective_key
    WHERE cq.character_id = :0
        AND cq.status = 'started'
        AND qo.target_type = :1
        AND qo.target_key = :2
    ORDER BY cqo.character_quest_id ASC, qo.order_index ASC, cqo.objective_key ASC
]]

local SELECT_MATCHING_STARTED_OBJECTIVES_WITHOUT_TARGET_KEY_QUERY = [[
    SELECT
        cqo.character_quest_id,
        cqo.objective_key,
        cqo.current_count,
        cqo.required_count,
        cqo.completed_at,
        cqo.created_at,
        cqo.updated_at,
        qo.quest_key,
        qo.description,
        qo.target_type,
        qo.target_key,
        qo.order_index
    FROM character_quest_objectives cqo
    INNER JOIN character_quests cq
        ON cq.id = cqo.character_quest_id
    INNER JOIN quest_objectives qo
        ON qo.quest_key = cq.quest_key
        AND qo.objective_key = cqo.objective_key
    WHERE cq.character_id = :0
        AND cq.status = 'started'
        AND qo.target_type = :1
        AND qo.target_key IS NULL
    ORDER BY cqo.character_quest_id ASC, qo.order_index ASC, cqo.objective_key ASC
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
    RETURNING
        id,
        character_id,
        quest_key,
        status,
        started_at,
        completed_at,
        created_at,
        updated_at
]]

local INSERT_CHARACTER_QUEST_OBJECTIVE_QUERY = [[
    INSERT INTO character_quest_objectives (
        character_quest_id,
        objective_key,
        required_count
    )
    VALUES (
        :0,
        :1,
        :2
    )
    ON CONFLICT (character_quest_id, objective_key) DO NOTHING
]]

local UPDATE_COMPLETE_CHARACTER_QUEST_QUERY = [[
    UPDATE character_quests
    SET
        status = 'completed',
        completed_at = NOW(),
        updated_at = NOW()
    WHERE id = :0
]]

local UPDATE_CHARACTER_QUEST_OBJECTIVE_PROGRESS_QUERY = [[
    UPDATE character_quest_objectives
    SET
        current_count = :0,
        updated_at = NOW()
    WHERE character_quest_id = :1
        AND objective_key = :2
]]

local UPDATE_CHARACTER_QUEST_OBJECTIVE_PROGRESS_COMPLETE_QUERY = [[
    UPDATE character_quest_objectives
    SET
        current_count = :0,
        completed_at = COALESCE(completed_at, NOW()),
        updated_at = NOW()
    WHERE character_quest_id = :1
        AND objective_key = :2
]]

local SELECT_CHARACTER_QUEST_OBJECTIVES_COMPLETION_QUERY = [[
    SELECT
        COUNT(*) AS total_count,
        SUM(
            CASE
                WHEN completed_at IS NOT NULL OR current_count >= required_count THEN 1
                ELSE 0
            END
        ) AS completed_count
    FROM character_quest_objectives
    WHERE character_quest_id = :0
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

local function normalize_objective_key(objective_key)
    local normalized_objective_key = trim_string(objective_key)

    if normalized_objective_key == nil then
        return nil
    end

    return string.lower(normalized_objective_key)
end

local function normalize_target_type(target_type)
    local normalized_target_type = trim_string(target_type)

    if normalized_target_type == nil then
        return nil
    end

    return string.lower(normalized_target_type)
end

local function normalize_target_key(target_key)
    local normalized_target_key = trim_string(target_key)

    if normalized_target_key == nil then
        return nil
    end

    return string.lower(normalized_target_key)
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
        reward_item_key = normalize_quest_key(row.reward_item_key),
        reward_item_quantity = normalize_non_negative_integer(row.reward_item_quantity, 0),
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
        reward_item_key = normalize_quest_key(row.reward_item_key),
        reward_item_quantity = normalize_non_negative_integer(row.reward_item_quantity, 0),
    }
end

local function normalize_quest_objective_row(row)
    local quest_key = nil
    local objective_key = nil
    local target_type = nil
    local required_count = nil

    if type(row) ~= "table" then
        return nil
    end

    quest_key = normalize_quest_key(row.quest_key)
    objective_key = normalize_objective_key(row.objective_key)
    target_type = normalize_target_type(row.target_type)
    required_count = normalize_positive_integer(row.required_count)

    if quest_key == nil or objective_key == nil or target_type == nil or required_count == nil then
        return nil
    end

    return {
        character_quest_id = normalize_positive_integer(row.character_quest_id),
        quest_key = quest_key,
        objective_key = objective_key,
        description = trim_string(row.description) or objective_key,
        target_type = target_type,
        target_key = normalize_target_key(row.target_key),
        required_count = required_count,
        order_index = normalize_non_negative_integer(row.order_index, 0),
        current_count = normalize_non_negative_integer(row.current_count, 0),
        completed_at = row.completed_at,
        created_at = row.created_at,
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

function QuestRepository:ListQuestObjectives(quest_key, callback)
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

        database_or_error:SelectAsync(SELECT_QUEST_OBJECTIVES_QUERY, function(rows, select_error)
            local objective_rows = nil

            if select_error ~= nil then
                callback(false, nil, select_error)
                return
            end

            objective_rows = normalize_rows(rows, normalize_quest_objective_row)

            Console.Log(
                "[gr_quests][repository] Quest objectives loaded quest_key=%s count=%s.",
                tostring(normalized_quest_key),
                tostring(#objective_rows)
            )

            callback(true, objective_rows, nil)
        end, normalized_quest_key)
    end, "quest-list-objectives")
end

function QuestRepository:ListCharacterQuestObjectives(character_quest_id, callback)
    local normalized_character_quest_id = normalize_positive_integer(character_quest_id)

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if normalized_character_quest_id == nil then
        callback(false, nil, "character-quest-id-required")
        return true
    end

    return self:Connect(function(is_connected, database_or_error, error)
        if not is_connected then
            callback(false, nil, error)
            return
        end

        database_or_error:SelectAsync(SELECT_CHARACTER_QUEST_OBJECTIVES_QUERY, function(rows, select_error)
            local objective_rows = nil

            if select_error ~= nil then
                callback(false, nil, select_error)
                return
            end

            objective_rows = normalize_rows(rows, normalize_quest_objective_row)
            callback(true, objective_rows, nil)
        end, normalized_character_quest_id)
    end, "quest-list-character-objectives")
end

function QuestRepository:InitializeQuestObjectives(character_quest_id, quest_key, callback)
    local normalized_character_quest_id = normalize_positive_integer(character_quest_id)
    local normalized_quest_key = normalize_quest_key(quest_key)

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if normalized_character_quest_id == nil then
        callback(false, nil, "character-quest-id-required")
        return true
    end

    if normalized_quest_key == nil then
        callback(false, nil, "quest-key-required")
        return true
    end

    return self:ListQuestObjectives(normalized_quest_key, function(is_objectives_success, objective_rows, objectives_error)
        if not is_objectives_success then
            callback(false, nil, objectives_error)
            return
        end

        if type(objective_rows) ~= "table" or #objective_rows == 0 then
            Console.Log(
                "[gr_quests][repository] Quest objectives initialized character_quest_id=%s quest_key=%s count=%s.",
                tostring(normalized_character_quest_id),
                tostring(normalized_quest_key),
                "0"
            )
            callback(true, {}, nil)
            return
        end

        self:Connect(function(is_connected, database_or_error, error)
            local objective_index = 1

            if not is_connected then
                callback(false, nil, error)
                return
            end

            local function insert_next_objective()
                local objective_row = objective_rows[objective_index]

                if objective_row == nil then
                    self:ListCharacterQuestObjectives(normalized_character_quest_id, function(is_list_success, initialized_rows, list_error)
                        if not is_list_success then
                            callback(false, nil, list_error)
                            return
                        end

                        Console.Log(
                            "[gr_quests][repository] Quest objectives initialized character_quest_id=%s quest_key=%s count=%s.",
                            tostring(normalized_character_quest_id),
                            tostring(normalized_quest_key),
                            tostring(#initialized_rows)
                        )

                        callback(true, initialized_rows, nil)
                    end)
                    return
                end

                database_or_error:ExecuteAsync(
                    INSERT_CHARACTER_QUEST_OBJECTIVE_QUERY,
                    function(_, insert_error)
                        if insert_error ~= nil then
                            callback(false, nil, insert_error)
                            return
                        end

                        objective_index = objective_index + 1
                        insert_next_objective()
                    end,
                    normalized_character_quest_id,
                    objective_row.objective_key,
                    objective_row.required_count
                )
            end

            insert_next_objective()
        end, "quest-initialize-objectives")
    end)
end

function QuestRepository:ListActiveCharacterQuestDetails(character_id, callback)
    local normalized_character_id = normalize_positive_integer(character_id)

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if normalized_character_id == nil then
        callback(false, nil, "character-id-required")
        return true
    end

    return self:ListCharacterQuests(normalized_character_id, function(is_quests_success, character_quests, quests_error)
        local quest_index = 1

        if not is_quests_success then
            callback(false, nil, quests_error)
            return
        end

        character_quests = character_quests or {}

        local function populate_next_quest()
            local character_quest_row = character_quests[quest_index]

            if character_quest_row == nil then
                callback(true, character_quests, nil)
                return
            end

            self:ListCharacterQuestObjectives(character_quest_row.id, function(is_objectives_success, objective_rows, objectives_error)
                if not is_objectives_success then
                    callback(false, nil, objectives_error)
                    return
                end

                character_quest_row.objectives = objective_rows or {}
                quest_index = quest_index + 1
                populate_next_quest()
            end)
        end

        populate_next_quest()
    end)
end

function QuestRepository:RecordObjectiveProgress(character_id, target_type, target_key, amount, callback)
    local normalized_character_id = normalize_positive_integer(character_id)
    local normalized_target_type = normalize_target_type(target_type)
    local normalized_target_key = normalize_target_key(target_key)
    local normalized_amount = normalize_positive_integer(amount)

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if normalized_character_id == nil then
        callback(false, nil, "character-id-required")
        return true
    end

    if normalized_target_type == nil then
        callback(false, nil, "target-type-required")
        return true
    end

    if normalized_amount == nil then
        callback(false, nil, "objective-progress-amount-required")
        return true
    end

    return self:Connect(function(is_connected, database_or_error, error)
        local select_query = nil

        if not is_connected then
            callback(false, nil, error)
            return
        end

        if normalized_target_key == nil then
            select_query = SELECT_MATCHING_STARTED_OBJECTIVES_WITHOUT_TARGET_KEY_QUERY
        else
            select_query = SELECT_MATCHING_STARTED_OBJECTIVES_WITH_TARGET_KEY_QUERY
        end

        local function handle_matching_rows(rows, select_error)
            local objective_rows = nil
            local objective_index = 1
            local updated_rows = {}

            if select_error ~= nil then
                callback(false, nil, select_error)
                return
            end

            objective_rows = normalize_rows(rows, normalize_quest_objective_row)

            if objective_rows[1] == nil then
                callback(false, nil, "quest-objective-not-found")
                return
            end

            local function update_next_objective()
                local objective_row = objective_rows[objective_index]

                if objective_row == nil then
                    Console.Log(
                        "[gr_quests][repository] Objective progress recorded character_id=%s target_type=%s target_key=%s updated_count=%s.",
                        tostring(normalized_character_id),
                        tostring(normalized_target_type),
                        tostring(normalized_target_key),
                        tostring(#updated_rows)
                    )
                    callback(true, updated_rows, nil)
                    return
                end

                local new_count = math.min(
                    objective_row.required_count,
                    objective_row.current_count + normalized_amount
                )

                local is_completed = new_count >= objective_row.required_count
                local update_query = UPDATE_CHARACTER_QUEST_OBJECTIVE_PROGRESS_QUERY

                if is_completed then
                    update_query = UPDATE_CHARACTER_QUEST_OBJECTIVE_PROGRESS_COMPLETE_QUERY
                end

                database_or_error:ExecuteAsync(
                    update_query,
                    function(rows_affected, update_error)
                        if update_error ~= nil then
                            callback(false, nil, update_error)
                            return
                        end

                        if rows_affected ~= 1 then
                            callback(false, nil, "character-quest-objective-update-unexpected-rows-affected")
                            return
                        end

                        objective_row.current_count = new_count

                        if is_completed and objective_row.completed_at == nil then
                            objective_row.completed_at = os.date("!%Y-%m-%dT%H:%M:%SZ")
                        end

                        updated_rows[#updated_rows + 1] = objective_row
                        objective_index = objective_index + 1
                        update_next_objective()
                    end,
                    new_count,
                    objective_row.character_quest_id,
                    objective_row.objective_key
                )
            end

            update_next_objective()
        end

        if normalized_target_key == nil then
            database_or_error:SelectAsync(
                select_query,
                handle_matching_rows,
                normalized_character_id,
                normalized_target_type
            )
            return
        end

        database_or_error:SelectAsync(
            select_query,
            handle_matching_rows,
            normalized_character_id,
            normalized_target_type,
            normalized_target_key
        )
    end, "quest-record-objective-progress")
end

function QuestRepository:AreQuestObjectivesCompleted(character_quest_id, callback)
    local normalized_character_quest_id = normalize_positive_integer(character_quest_id)

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if normalized_character_quest_id == nil then
        callback(false, nil, "character-quest-id-required")
        return true
    end

    return self:Connect(function(is_connected, database_or_error, error)
        if not is_connected then
            callback(false, nil, error)
            return
        end

        database_or_error:SelectAsync(SELECT_CHARACTER_QUEST_OBJECTIVES_COMPLETION_QUERY, function(rows, select_error)
            local summary_row = rows and rows[1] or nil
            local total_count = normalize_non_negative_integer(summary_row and summary_row.total_count, 0)
            local completed_count = normalize_non_negative_integer(summary_row and summary_row.completed_count, 0)
            local has_objectives = total_count > 0
            local is_completed = (not has_objectives) or (completed_count >= total_count)

            if select_error ~= nil then
                callback(false, nil, select_error)
                return
            end

            Console.Log(
                "[gr_quests][repository] Quest objectives completion checked character_quest_id=%s completed=%s.",
                tostring(normalized_character_quest_id),
                tostring(is_completed)
            )

            callback(true, {
                has_objectives = has_objectives,
                completed = is_completed,
                total_count = total_count,
                completed_count = completed_count,
            }, nil)
        end, normalized_character_quest_id)
    end, "quest-check-objectives-completed")
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

                database_or_error:SelectAsync(INSERT_CHARACTER_QUEST_QUERY, function(insert_rows, insert_error)
                    local normalized_insert_rows = nil
                    local started_row = nil

                    if insert_error ~= nil then
                        callback(false, nil, insert_error)
                        return
                    end

                    normalized_insert_rows = normalize_rows(insert_rows, normalize_character_quest_row)
                    started_row = normalized_insert_rows[1]

                    if started_row == nil then
                        callback(false, nil, "character-quest-create-returning-missing")
                        return
                    end

                    started_row.title = quest_row.title
                    started_row.reward_xp = quest_row.reward_xp
                    started_row.reward_item_key = quest_row.reward_item_key
                    started_row.reward_item_quantity = quest_row.reward_item_quantity

                    self:InitializeQuestObjectives(started_row.id, normalized_quest_key, function(is_init_success, objective_rows, init_error)
                        if not is_init_success then
                            callback(false, nil, init_error)
                            return
                        end

                        started_row.objectives = objective_rows or {}

                        Console.Log(
                            "[gr_quests][repository] Quest started character_id=%s quest_key=%s.",
                            tostring(normalized_character_id),
                            tostring(normalized_quest_key)
                        )

                        callback(true, started_row, nil)
                    end)
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

            database_or_error:ExecuteAsync(UPDATE_COMPLETE_CHARACTER_QUEST_QUERY, function(rows_affected, execute_error)
                if execute_error ~= nil then
                    callback(false, nil, execute_error)
                    return
                end

                if rows_affected ~= 1 then
                    callback(false, nil, "character-quest-complete-unexpected-rows-affected")
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

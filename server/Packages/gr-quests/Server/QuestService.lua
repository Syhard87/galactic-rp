GRQuests = GRQuests or {}
GRQuests.Server = GRQuests.Server or {}

local QuestService = {}
QuestService.__index = QuestService

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

local function resolve_active_character_id(player_or_platform_id)
    local active_character = nil

    if type(GRCharactersBridge) ~= "table" or type(GRCharactersBridge.GetActiveCharacter) ~= "function" then
        return nil, "characters-bridge-unavailable"
    end

    active_character = GRCharactersBridge.GetActiveCharacter(player_or_platform_id)

    if type(active_character) ~= "table" or active_character.id == nil then
        return nil, "active-character-missing"
    end

    return normalize_positive_integer(active_character.id), nil
end

local function callback_repository_missing(callback)
    if type(callback) == "function" then
        callback(false, nil, "quest-repository-missing")
    end

    return true
end

function QuestService.Create(repository)
    local self = setmetatable({}, QuestService)

    self.repository = repository

    return self
end

function QuestService:ListAvailableQuests(callback)
    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if self.repository == nil then
        return callback_repository_missing(callback)
    end

    return self.repository:ListAvailableQuests(callback)
end

function QuestService:ListActiveCharacterQuests(player_or_platform_id, callback)
    local active_character_id = nil
    local resolve_error = nil

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if self.repository == nil then
        return callback_repository_missing(callback)
    end

    active_character_id, resolve_error = resolve_active_character_id(player_or_platform_id)

    if active_character_id == nil then
        callback(false, nil, resolve_error)
        return true
    end

    return self.repository:ListActiveCharacterQuestDetails(active_character_id, callback)
end

function QuestService:StartQuestForActiveCharacter(player_or_platform_id, quest_key, callback)
    local active_character_id = nil
    local resolve_error = nil

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if self.repository == nil then
        return callback_repository_missing(callback)
    end

    active_character_id, resolve_error = resolve_active_character_id(player_or_platform_id)

    if active_character_id == nil then
        callback(false, nil, resolve_error)
        return true
    end

    return self.repository:StartQuest(active_character_id, quest_key, callback)
end

function QuestService:AbandonQuestForActiveCharacter(player_or_platform_id, quest_key, callback)
    local active_character_id = nil
    local resolve_error = nil

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if self.repository == nil then
        return callback_repository_missing(callback)
    end

    active_character_id, resolve_error = resolve_active_character_id(player_or_platform_id)

    if active_character_id == nil then
        callback(false, nil, resolve_error)
        return true
    end

    return self.repository:AbandonQuest(active_character_id, quest_key, callback)
end

function QuestService:RecordObjectiveProgress(character_id, target_type, target_key, amount, callback)
    local normalized_character_id = normalize_positive_integer(character_id)

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if self.repository == nil then
        return callback_repository_missing(callback)
    end

    if normalized_character_id == nil then
        callback(false, nil, "character-id-required")
        return true
    end

    return self.repository:RecordObjectiveProgress(
        normalized_character_id,
        target_type,
        target_key,
        amount,
        callback
    )
end

function QuestService:RecordObjectiveProgressForActiveCharacter(player_or_platform_id, target_type, target_key, amount, callback)
    local active_character_id = nil
    local resolve_error = nil

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if self.repository == nil then
        return callback_repository_missing(callback)
    end

    active_character_id, resolve_error = resolve_active_character_id(player_or_platform_id)

    if active_character_id == nil then
        callback(false, nil, resolve_error)
        return true
    end

    return self:RecordObjectiveProgress(active_character_id, target_type, target_key, amount, callback)
end

function QuestService:CompleteQuestForActiveCharacter(player_or_platform_id, quest_key, callback)
    local active_character_id = nil
    local resolve_error = nil
    local normalized_quest_key = trim_string(quest_key)

    if normalized_quest_key ~= nil then
        normalized_quest_key = string.lower(normalized_quest_key)
    end

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if self.repository == nil then
        return callback_repository_missing(callback)
    end

    active_character_id, resolve_error = resolve_active_character_id(player_or_platform_id)

    if active_character_id == nil then
        callback(false, nil, resolve_error)
        return true
    end

    return self.repository:GetQuestByKey(normalized_quest_key, function(is_quest_success, quest_row, quest_error)
        if not is_quest_success then
            callback(false, nil, quest_error)
            return
        end

        if quest_row == nil then
            callback(false, nil, "quest-not-found")
            return
        end

        self.repository:ListCharacterQuests(active_character_id, function(is_character_quests_success, character_quests, character_quests_error)
            local started_character_quest_row = nil

            if not is_character_quests_success then
                callback(false, nil, character_quests_error)
                return
            end

            for _, character_quest_row in ipairs(character_quests or {}) do
                if character_quest_row.quest_key == normalized_quest_key and character_quest_row.status == "started" then
                    started_character_quest_row = character_quest_row
                    break
                end
            end

            if started_character_quest_row == nil then
                callback(false, nil, "quest-not-started")
                return
            end

            self.repository:AreQuestObjectivesCompleted(started_character_quest_row.id, function(is_check_success, completion_state, completion_error)
                if not is_check_success then
                    callback(false, nil, completion_error)
                    return
                end

                if completion_state ~= nil and completion_state.has_objectives == true and completion_state.completed ~= true then
                    callback(false, nil, "quest-objectives-incomplete")
                    return
                end

                self.repository:CompleteQuest(active_character_id, normalized_quest_key, function(is_complete_success, character_quest_row, complete_error)
                    local result = nil

                    if not is_complete_success then
                        callback(false, nil, complete_error)
                        return
                    end

                    result = {
                        quest = quest_row,
                        character_quest = character_quest_row,
                        reward_xp_granted = 0,
                        reward_item_key = nil,
                        reward_item_quantity = 0,
                        reward_skill_key = nil,
                        reward_skill_xp = 0,
                        reward_reputation_key = nil,
                        reward_reputation_amount = 0,
                    }

                    local function grant_reputation_reward()
                        local reward_reputation_amount = normalize_integer(quest_row.reward_reputation_amount, 0)

                        if quest_row.reward_reputation_key == nil or reward_reputation_amount == 0 then
                            Console.Log(
                                "[gr_quests][service] Quest has no reputation reward quest_key=%s.",
                                tostring(quest_row.key)
                            )
                            callback(true, result, nil)
                            return
                        end

                        if type(GRReputationBridge) ~= "table" or type(GRReputationBridge.AddReputation) ~= "function" then
                            Console.Log(
                                "[gr_quests][service] Quest reputation reward skipped reason=reputation-bridge-unavailable quest_key=%s.",
                                tostring(quest_row.key)
                            )
                            callback(true, result, nil)
                            return
                        end

                        GRReputationBridge.AddReputation(
                            active_character_id,
                            quest_row.reward_reputation_key,
                            reward_reputation_amount,
                            string.format("quest:%s", tostring(quest_row.key)),
                            function(is_reputation_success, _, reputation_error)
                                if not is_reputation_success then
                                    Console.Log(
                                        "[gr_quests][service] Quest reputation reward failed character_id=%s quest_key=%s reputation_key=%s reason=%s.",
                                        tostring(active_character_id),
                                        tostring(quest_row.key),
                                        tostring(quest_row.reward_reputation_key),
                                        tostring(reputation_error)
                                    )
                                    callback(true, result, nil)
                                    return
                                end

                                result.reward_reputation_key = quest_row.reward_reputation_key
                                result.reward_reputation_amount = reward_reputation_amount

                                Console.Log(
                                    "[gr_quests][service] Quest reputation reward granted character_id=%s quest_key=%s reputation_key=%s amount=%s.",
                                    tostring(active_character_id),
                                    tostring(quest_row.key),
                                    tostring(quest_row.reward_reputation_key),
                                    tostring(reward_reputation_amount)
                                )

                                callback(true, result, nil)
                            end
                        )
                    end

                    local function grant_skill_reward()
                        if quest_row.reward_skill_key == nil or quest_row.reward_skill_xp == nil or quest_row.reward_skill_xp < 1 then
                            Console.Log(
                                "[gr_quests][service] Quest has no skill reward quest_key=%s.",
                                tostring(quest_row.key)
                            )
                            grant_reputation_reward()
                            return
                        end

                        if type(GRSkillsBridge) ~= "table" or type(GRSkillsBridge.AddSkillXp) ~= "function" then
                            Console.Log(
                                "[gr_quests][service] Quest skill reward skipped reason=skills-bridge-unavailable quest_key=%s.",
                                tostring(quest_row.key)
                            )
                            grant_reputation_reward()
                            return
                        end

                        GRSkillsBridge.AddSkillXp(
                            active_character_id,
                            quest_row.reward_skill_key,
                            quest_row.reward_skill_xp,
                            string.format("quest:%s", tostring(quest_row.key)),
                            function(is_skill_success, _, skill_error)
                                if not is_skill_success then
                                    Console.Log(
                                        "[gr_quests][service] Quest skill reward failed character_id=%s quest_key=%s skill_key=%s reason=%s.",
                                        tostring(active_character_id),
                                        tostring(quest_row.key),
                                        tostring(quest_row.reward_skill_key),
                                        tostring(skill_error)
                                    )
                                    grant_reputation_reward()
                                    return
                                end

                                result.reward_skill_key = quest_row.reward_skill_key
                                result.reward_skill_xp = quest_row.reward_skill_xp

                                Console.Log(
                                    "[gr_quests][service] Quest skill reward granted character_id=%s quest_key=%s skill_key=%s amount=%s.",
                                    tostring(active_character_id),
                                    tostring(quest_row.key),
                                    tostring(quest_row.reward_skill_key),
                                    tostring(quest_row.reward_skill_xp)
                                )

                                grant_reputation_reward()
                            end
                        )
                    end

                    local function grant_item_reward()
                        if quest_row.reward_item_key == nil or quest_row.reward_item_quantity == nil or quest_row.reward_item_quantity < 1 then
                            Console.Log(
                                "[gr_quests][service] Quest has no item reward quest_key=%s.",
                                tostring(quest_row.key)
                            )
                            grant_skill_reward()
                            return
                        end

                        if type(GRInventoryBridge) ~= "table" or type(GRInventoryBridge.AddItem) ~= "function" then
                            Console.Log(
                                "[gr_quests][service] Quest item reward skipped reason=inventory-bridge-unavailable quest_key=%s.",
                                tostring(quest_row.key)
                            )
                            grant_skill_reward()
                            return
                        end

                        GRInventoryBridge.AddItem(active_character_id, quest_row.reward_item_key, quest_row.reward_item_quantity, nil, function(is_item_success, _, item_error)
                            if not is_item_success then
                                Console.Log(
                                    "[gr_quests][service] Quest item reward failed character_id=%s quest_key=%s item_key=%s reason=%s.",
                                    tostring(active_character_id),
                                    tostring(quest_row.key),
                                    tostring(quest_row.reward_item_key),
                                    tostring(item_error)
                                )
                                grant_skill_reward()
                                return
                            end

                            result.reward_item_key = quest_row.reward_item_key
                            result.reward_item_quantity = quest_row.reward_item_quantity

                            Console.Log(
                                "[gr_quests][service] Quest item reward granted character_id=%s quest_key=%s item_key=%s quantity=%s.",
                                tostring(active_character_id),
                                tostring(quest_row.key),
                                tostring(quest_row.reward_item_key),
                                tostring(quest_row.reward_item_quantity)
                            )

                            grant_skill_reward()
                        end)
                    end

                    if quest_row.reward_xp == nil or quest_row.reward_xp < 1 then
                        grant_item_reward()
                        return
                    end

                    if type(GRProgressionBridge) ~= "table" or type(GRProgressionBridge.AddXp) ~= "function" then
                        Console.Log(
                            "[gr_quests][service] Quest reward XP skipped quest_key=%s reason=%s.",
                            tostring(quest_row.key),
                            "progression-bridge-unavailable"
                        )
                        grant_item_reward()
                        return
                    end

                    GRProgressionBridge.AddXp(active_character_id, quest_row.reward_xp, string.format("quest:%s", tostring(quest_row.key)), function(is_xp_success, _, xp_error)
                        if not is_xp_success then
                            Console.Log(
                                "[gr_quests][service] Quest reward XP failed character_id=%s quest_key=%s reason=%s.",
                                tostring(active_character_id),
                                tostring(quest_row.key),
                                tostring(xp_error)
                            )
                            grant_item_reward()
                            return
                        end

                        result.reward_xp_granted = quest_row.reward_xp

                        Console.Log(
                            "[gr_quests][service] Quest reward XP granted character_id=%s quest_key=%s amount=%s.",
                            tostring(active_character_id),
                            tostring(quest_row.key),
                            tostring(quest_row.reward_xp)
                        )

                        grant_item_reward()
                    end)
                end)
            end)
        end)
    end)
end

GRQuests.Server.QuestServiceClass = QuestService

return QuestService

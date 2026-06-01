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

    return self.repository:ListCharacterQuests(active_character_id, callback)
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

function QuestService:CompleteQuestForActiveCharacter(player_or_platform_id, quest_key, callback)
    local active_character_id = nil
    local resolve_error = nil
    local normalized_quest_key = trim_string(quest_key)

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
            }

            local function grant_item_reward()
                if quest_row.reward_item_key == nil or quest_row.reward_item_quantity == nil or quest_row.reward_item_quantity < 1 then
                    Console.Log(
                        "[gr_quests][service] Quest has no item reward quest_key=%s.",
                        tostring(quest_row.key)
                    )
                    callback(true, result, nil)
                    return
                end

                if type(GRInventoryBridge) ~= "table" or type(GRInventoryBridge.AddItem) ~= "function" then
                    Console.Log(
                        "[gr_quests][service] Quest item reward skipped reason=inventory-bridge-unavailable quest_key=%s.",
                        tostring(quest_row.key)
                    )
                    callback(true, result, nil)
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
                        callback(true, result, nil)
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

                    callback(true, result, nil)
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
end

GRQuests.Server.QuestServiceClass = QuestService

return QuestService

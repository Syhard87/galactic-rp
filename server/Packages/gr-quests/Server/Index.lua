Package.Require("../Shared/Index.lua")
Package.Require("../Shared/QuestConfig.lua")

local QuestRepository = Package.Require("QuestRepository.lua")
local QuestService = Package.Require("QuestService.lua")

GRQuests = GRQuests or {}
GRQuests.Server = GRQuests.Server or {}

local function resolve_database_service()
    if type(GRDatabaseBridge) == "table" and type(GRDatabaseBridge.GetService) == "function" then
        return GRDatabaseBridge.GetService()
    end

    return nil
end

local function callback_service_missing(callback)
    if type(callback) == "function" then
        callback(false, nil, "quests-service-missing")
    end

    return true
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

local function get_platform_id(player)
    if type(player) ~= "table" and type(player) ~= "userdata" then
        return nil
    end

    if type(player.GetAccountID) ~= "function" then
        return nil
    end

    return player:GetAccountID()
end

local function normalize_chat_submit_arguments(first_argument, second_argument)
    if get_platform_id(first_argument) ~= nil then
        return first_argument, second_argument
    end

    if get_platform_id(second_argument) ~= nil then
        return second_argument, first_argument
    end

    return nil, nil
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

local function get_chat_command(message)
    local trimmed_message = trim_string(message)

    if trimmed_message == nil or trimmed_message:sub(1, 1) ~= "/" then
        return nil, nil
    end

    local command_name, payload = trimmed_message:match("^/(%S+)%s*(.*)$")

    if command_name == nil then
        return nil, nil
    end

    return string.lower(command_name), trim_string(payload)
end

local database_service = resolve_database_service()

GRQuests.Server.Repository = QuestRepository.Create(database_service)
GRQuests.Server.Service = QuestService.Create(GRQuests.Server.Repository)

if database_service ~= nil then
    Console.Log("[gr_quests][server] Database service resolved through GRDatabaseBridge.")
else
    Console.Log("[gr_quests][server] Database service unavailable because GRDatabaseBridge is missing.")
end

local GRQuestsBridge = {
    GetService = function()
        return GRQuests.Server.Service
    end,
    ListAvailableQuests = function(callback)
        if GRQuests.Server.Service == nil then
            return callback_service_missing(callback)
        end

        return GRQuests.Server.Service:ListAvailableQuests(callback)
    end,
    ListActiveCharacterQuests = function(player_or_platform_id, callback)
        if GRQuests.Server.Service == nil then
            return callback_service_missing(callback)
        end

        return GRQuests.Server.Service:ListActiveCharacterQuests(player_or_platform_id, callback)
    end,
    StartQuestForActiveCharacter = function(player_or_platform_id, quest_key, callback)
        if GRQuests.Server.Service == nil then
            return callback_service_missing(callback)
        end

        return GRQuests.Server.Service:StartQuestForActiveCharacter(player_or_platform_id, quest_key, callback)
    end,
    CompleteQuestForActiveCharacter = function(player_or_platform_id, quest_key, callback)
        if GRQuests.Server.Service == nil then
            return callback_service_missing(callback)
        end

        return GRQuests.Server.Service:CompleteQuestForActiveCharacter(player_or_platform_id, quest_key, callback)
    end,
}

Package.Export("GRQuestsBridge", GRQuestsBridge)

if type(Chat) == "table" and type(Chat.Subscribe) == "function" and type(Chat.SendMessage) == "function" then
    Chat.Subscribe("PlayerSubmit", function(first_argument, second_argument)
        local player, message = normalize_chat_submit_arguments(first_argument, second_argument)
        local command_name = nil
        local payload = nil

        if player == nil then
            return
        end

        command_name, payload = get_chat_command(message)

        if command_name == "quests" then
            GRQuests.Server.Service:ListAvailableQuests(function(is_available_success, available_quests)
                if not is_available_success then
                    Chat.SendMessage(player, "Quetes indisponibles.")
                    return
                end

                Chat.SendMessage(player, "Quetes disponibles :")

                for _, quest_row in ipairs(available_quests or {}) do
                    Chat.SendMessage(
                        player,
                        string.format("- %s : %s", tostring(quest_row.key), tostring(quest_row.title))
                    )
                end

                GRQuests.Server.Service:ListActiveCharacterQuests(player, function(is_character_success, character_quests, character_error)
                    if not is_character_success then
                        if character_error == "active-character-missing" then
                            Chat.SendMessage(player, "Aucun personnage actif.")
                            return
                        end

                        Chat.SendMessage(player, "Mes quetes : indisponibles")
                        return
                    end

                    if type(character_quests) ~= "table" or #character_quests < 1 then
                        Chat.SendMessage(player, "Mes quetes : aucune")
                        return
                    end

                    Chat.SendMessage(player, "Mes quetes :")

                    for _, character_quest_row in ipairs(character_quests) do
                        Chat.SendMessage(
                            player,
                            string.format("- %s : %s", tostring(character_quest_row.quest_key), tostring(character_quest_row.status))
                        )
                    end
                end)
            end)

            return false
        end

        if command_name == "startquest" then
            if payload == nil then
                Chat.SendMessage(player, "Usage : /startquest <quest_key>")
                return false
            end

            GRQuests.Server.Service:StartQuestForActiveCharacter(player, payload, function(is_success, character_quest_row, error)
                if not is_success then
                    if error == "active-character-missing" then
                        Chat.SendMessage(player, "Aucun personnage actif.")
                        return
                    end

                    if error == "quest-not-found" or error == "quest-key-required" then
                        Chat.SendMessage(player, "Quete inconnue.")
                        return
                    end

                    if error == "quest-already-started" then
                        Chat.SendMessage(player, "Quete deja demarree.")
                        return
                    end

                    Chat.SendMessage(player, "Impossible de demarrer la quete.")
                    return
                end

                Chat.SendMessage(player, string.format("Quete demarree : %s", tostring(character_quest_row.quest_key)))
            end)

            return false
        end

        if command_name == "completequest" then
            if payload == nil then
                Chat.SendMessage(player, "Usage : /completequest <quest_key>")
                return false
            end

            GRQuests.Server.Service:CompleteQuestForActiveCharacter(player, payload, function(is_success, result, error)
                local reward_xp_granted = normalize_positive_integer(result and result.reward_xp_granted) or 0
                local quest_key = tostring(result and result.quest and result.quest.key or payload)

                if not is_success then
                    if error == "active-character-missing" then
                        Chat.SendMessage(player, "Aucun personnage actif.")
                        return
                    end

                    if error == "quest-not-found" or error == "quest-key-required" then
                        Chat.SendMessage(player, "Quete inconnue.")
                        return
                    end

                    if error == "quest-not-started" then
                        Chat.SendMessage(player, "Quete non demarree.")
                        return
                    end

                    Chat.SendMessage(player, "Impossible de terminer la quete.")
                    return
                end

                Chat.SendMessage(player, string.format("Quete terminee : %s", quest_key))

                if reward_xp_granted > 0 then
                    Chat.SendMessage(player, string.format("XP gagnee : %s", tostring(reward_xp_granted)))
                end
            end)

            return false
        end
    end)
end

Console.Log("[gr_quests][server] Quests package loaded.")
Console.Log("[gr_quests][server] Quests bridge exported.")

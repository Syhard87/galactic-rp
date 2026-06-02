Package.Require("../Shared/Index.lua")
Package.Require("../Shared/QuestConfig.lua")

local QuestRepository = Package.Require("QuestRepository.lua")
local QuestService = Package.Require("QuestService.lua")

GRQuests = GRQuests or {}
GRQuests.Server = GRQuests.Server or {}

local MAX_EXPLORATION_REPORT_LENGTH = 240

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

local function sanitize_chat_message(message)
    if type(message) ~= "string" then
        return nil
    end

    return message:gsub("[<>]", "")
end

local function normalize_boolean(value, fallback)
    if type(value) == "boolean" then
        return value
    end

    local string_value = trim_string(value)

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

local function get_platform_id(player)
    if type(player) ~= "table" and type(player) ~= "userdata" then
        return nil
    end

    if type(player.GetAccountID) ~= "function" then
        return nil
    end

    return player:GetAccountID()
end

local function resolve_platform_id(player_or_platform_id)
    local platform_id = get_platform_id(player_or_platform_id)

    if platform_id ~= nil then
        return platform_id
    end

    return trim_string(player_or_platform_id)
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

local function get_active_character_from_bridge(player_or_platform_id)
    if type(GRCharactersBridge) ~= "table" or type(GRCharactersBridge.GetActiveCharacter) ~= "function" then
        return nil, "characters-bridge-unavailable"
    end

    local active_character = GRCharactersBridge.GetActiveCharacter(player_or_platform_id)

    if type(active_character) ~= "table" or active_character.id == nil then
        return nil, "active-character-missing"
    end

    return active_character, nil
end

local function parse_platform_id_allowlist(value)
    local allowlist = {}
    local has_entries = false

    local function add_entry(entry_value)
        local normalized_entry = trim_string(entry_value)

        if normalized_entry == nil then
            return
        end

        allowlist[normalized_entry] = true
        has_entries = true
    end

    if type(value) == "string" then
        for raw_entry in string.gmatch(value, "([^,]+)") do
            add_entry(raw_entry)
        end
    elseif type(value) == "table" then
        for _, entry_value in ipairs(value) do
            add_entry(entry_value)
        end
    end

    return allowlist, has_entries
end

local function can_use_questprogress_command(player_or_platform_id)
    local platform_id = resolve_platform_id(player_or_platform_id)
    local custom_settings = nil
    local debug_commands_enabled = false
    local allowlist = nil
    local has_allowlist_entries = false

    if platform_id == nil then
        return false, nil, "platform-id-missing"
    end

    custom_settings = read_custom_settings()

    if type(custom_settings) ~= "table" then
        return false, platform_id, "custom-settings-missing"
    end

    debug_commands_enabled = normalize_boolean(custom_settings.gr_quests_debug_commands_enabled, false)

    if not debug_commands_enabled then
        return false, platform_id, "debug-disabled"
    end

    allowlist, has_allowlist_entries = parse_platform_id_allowlist(custom_settings.gr_quests_debug_allowed_platform_ids)

    if not has_allowlist_entries then
        return false, platform_id, "allowlist-missing"
    end

    if allowlist[platform_id] ~= true then
        return false, platform_id, "not-authorized"
    end

    return true, platform_id, nil
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
    AbandonQuestForActiveCharacter = function(player_or_platform_id, quest_key, callback)
        if GRQuests.Server.Service == nil then
            return callback_service_missing(callback)
        end

        return GRQuests.Server.Service:AbandonQuestForActiveCharacter(player_or_platform_id, quest_key, callback)
    end,
    CompleteQuestForActiveCharacter = function(player_or_platform_id, quest_key, callback)
        if GRQuests.Server.Service == nil then
            return callback_service_missing(callback)
        end

        return GRQuests.Server.Service:CompleteQuestForActiveCharacter(player_or_platform_id, quest_key, callback)
    end,
    RecordObjectiveProgress = function(character_id, target_type, target_key, amount, callback)
        if GRQuests.Server.Service == nil then
            return callback_service_missing(callback)
        end

        return GRQuests.Server.Service:RecordObjectiveProgress(character_id, target_type, target_key, amount, callback)
    end,
    RecordObjectiveProgressForActiveCharacter = function(player_or_platform_id, target_type, target_key, amount, callback)
        if GRQuests.Server.Service == nil then
            return callback_service_missing(callback)
        end

        return GRQuests.Server.Service:RecordObjectiveProgressForActiveCharacter(
            player_or_platform_id,
            target_type,
            target_key,
            amount,
            callback
        )
    end,
}

Package.Export("GRQuestsBridge", GRQuestsBridge)

local function record_exploration_report_objective_progress(player_or_platform_id)
    local platform_id = resolve_platform_id(player_or_platform_id)

    if type(GRQuestsBridge) ~= "table" or type(GRQuestsBridge.RecordObjectiveProgressForActiveCharacter) ~= "function" then
        Console.Log(
            "[gr_quests][server] Exploration report objective progress skipped reason=quests-bridge-unavailable."
        )
        return
    end

    GRQuestsBridge.RecordObjectiveProgressForActiveCharacter(
        player_or_platform_id,
        "rp_action",
        "exploration_report",
        1,
        function(is_success, _, error)
            if not is_success then
                Console.Log(
                    "[gr_quests][server] Exploration report objective progress skipped reason=%s.",
                    tostring(error or "objective-progress-failed")
                )
                return
            end

            Console.Log(
                "[gr_quests][server] Exploration report objective progress recorded platform_id=%s.",
                tostring(platform_id)
            )
        end
    )
end

local function grant_exploration_report_skill_xp(player_or_platform_id)
    local platform_id = resolve_platform_id(player_or_platform_id)

    if type(GRSkillsBridge) ~= "table" or type(GRSkillsBridge.AddSkillXpToActiveCharacter) ~= "function" then
        Console.Log(
            "[gr_quests][server] Exploration report skill XP skipped reason=skills-bridge-unavailable."
        )
        return
    end

    GRSkillsBridge.AddSkillXpToActiveCharacter(
        player_or_platform_id,
        "exploration",
        15,
        "rp_action:exploration_report",
        function(is_success, _, error)
            if not is_success then
                Console.Log(
                    "[gr_quests][server] Exploration report skill XP skipped reason=%s.",
                    tostring(error or "skill-xp-failed")
                )
                return
            end

            Console.Log(
                "[gr_quests][server] Exploration report skill XP granted platform_id=%s skill_key=exploration amount=15.",
                tostring(platform_id)
            )
        end
    )
end

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

                        if type(character_quest_row.objectives) == "table" then
                            for _, objective_row in ipairs(character_quest_row.objectives) do
                                Chat.SendMessage(
                                    player,
                                    string.format(
                                        "  * %s %s/%s - %s",
                                        tostring(objective_row.objective_key),
                                        tostring(objective_row.current_count or 0),
                                        tostring(objective_row.required_count or 0),
                                        tostring(objective_row.description or objective_row.objective_key)
                                    )
                                )
                            end
                        end
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
                    local required_reputation_key = trim_string(character_quest_row and character_quest_row.required_reputation_key)
                    local required_reputation_min_value = tonumber(character_quest_row and character_quest_row.required_reputation_min_value) ~= nil and math.floor(tonumber(character_quest_row.required_reputation_min_value)) or 0
                    local actual_reputation_value = tonumber(character_quest_row and character_quest_row.actual_reputation_value) ~= nil and math.floor(tonumber(character_quest_row.actual_reputation_value)) or 0

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

                    if error == "quest-already-completed" then
                        Chat.SendMessage(player, "Quete deja terminee.")
                        return
                    end

                    if error == "quest-reputation-insufficient" and required_reputation_key ~= nil then
                        Chat.SendMessage(
                            player,
                            string.format(
                                "Quete indisponible : reputation %s insuffisante. Requis=%s actuel=%s.",
                                required_reputation_key,
                                tostring(required_reputation_min_value),
                                tostring(actual_reputation_value)
                            )
                        )
                        return
                    end

                    if error == "quest-reputation-check-unavailable" then
                        Chat.SendMessage(player, "Quete indisponible : verification de reputation impossible.")
                        return
                    end

                    Chat.SendMessage(player, "Impossible de demarrer la quete.")
                    return
                end

                Chat.SendMessage(player, string.format("Quete demarree : %s", tostring(character_quest_row.quest_key)))
            end)

            return false
        end

        if command_name == "abandonquest" then
            if payload == nil then
                Chat.SendMessage(player, "Usage : /abandonquest <quest_key>")
                return false
            end

            GRQuests.Server.Service:AbandonQuestForActiveCharacter(player, payload, function(is_success, character_quest_row, error)
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

                    if error == "quest-already-completed" then
                        Chat.SendMessage(player, "Quete deja terminee.")
                        return
                    end

                    Chat.SendMessage(player, "Impossible d'abandonner la quete.")
                    return
                end

                Chat.SendMessage(player, string.format("Quete abandonnee : %s", tostring(character_quest_row.quest_key)))
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
                local reward_item_quantity = normalize_positive_integer(result and result.reward_item_quantity) or 0
                local reward_item_key = trim_string(result and result.reward_item_key)
                local reward_skill_xp = normalize_positive_integer(result and result.reward_skill_xp) or 0
                local reward_skill_key = trim_string(result and result.reward_skill_key)
                local reward_reputation_key = trim_string(result and result.reward_reputation_key)
                local reward_reputation_amount = tonumber(result and result.reward_reputation_amount) ~= nil and math.floor(tonumber(result and result.reward_reputation_amount)) or 0
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

                    if error == "quest-objectives-incomplete" then
                        Chat.SendMessage(player, "Objectifs de quete incomplets.")
                        return
                    end

                    Chat.SendMessage(player, "Impossible de terminer la quete.")
                    return
                end

                Chat.SendMessage(player, string.format("Quete terminee : %s", quest_key))

                if reward_xp_granted > 0 then
                    Chat.SendMessage(player, string.format("XP gagnee : %s", tostring(reward_xp_granted)))
                end

                if reward_item_key ~= nil and reward_item_quantity > 0 then
                    Chat.SendMessage(
                        player,
                        string.format("Objet gagne : %s x%s", reward_item_key, tostring(reward_item_quantity))
                    )
                end

                if reward_skill_key ~= nil and reward_skill_xp > 0 then
                    Chat.SendMessage(
                        player,
                        string.format("XP competence gagnee : %s x%s", reward_skill_key, tostring(reward_skill_xp))
                    )
                end

                if reward_reputation_key ~= nil and reward_reputation_amount ~= 0 then
                    Chat.SendMessage(
                        player,
                        string.format(
                            "Reputation gagnee : %s %s",
                            reward_reputation_key,
                            reward_reputation_amount > 0 and ("+" .. tostring(reward_reputation_amount)) or tostring(reward_reputation_amount)
                        )
                    )
                end
            end)

            return false
        end

        if command_name == "explorereport" then
            local active_character = nil
            local sanitized_payload = trim_string(sanitize_chat_message(payload))
            local platform_id = resolve_platform_id(player)

            if sanitized_payload == nil then
                Chat.SendMessage(player, "Usage : /explorereport <texte>")
                return false
            end

            if #sanitized_payload > MAX_EXPLORATION_REPORT_LENGTH then
                Chat.SendMessage(player, "Rapport trop long.")
                return false
            end

            active_character = get_active_character_from_bridge(player)

            if active_character == nil then
                Chat.SendMessage(player, "Aucun personnage actif.")
                return false
            end

            Console.Log(
                "[gr_quests][server] Exploration report submitted platform_id=%s character_id=%s text=%s.",
                tostring(platform_id),
                tostring(active_character.id),
                tostring(sanitized_payload)
            )

            Chat.SendMessage(player, "Rapport d'exploration envoye.")
            record_exploration_report_objective_progress(player)
            grant_exploration_report_skill_xp(player)

            return false
        end

        if command_name == "questprogress" then
            local is_allowed = false
            local platform_id = nil
            local guard_error = nil
            local target_type = nil
            local target_key = nil
            local amount_text = nil
            local amount = nil

            is_allowed, platform_id, guard_error = can_use_questprogress_command(player)

            if not is_allowed then
                Console.Log(
                    "[gr_quests][server] Quest progress command denied platform_id=%s reason=%s.",
                    tostring(platform_id),
                    tostring(guard_error)
                )
                Chat.SendMessage(player, "Commande reservee au staff/dev.")
                return false
            end

            if payload == nil then
                Chat.SendMessage(player, "Usage : /questprogress <target_type> <target_key> <amount>")
                return false
            end

            target_type, target_key, amount_text = payload:match("^(%S+)%s+(%S+)%s+(%S+)$")
            amount = normalize_positive_integer(amount_text)

            if trim_string(target_type) == nil or trim_string(target_key) == nil or amount == nil then
                Chat.SendMessage(player, "Usage : /questprogress <target_type> <target_key> <amount>")
                return false
            end

            GRQuests.Server.Service:RecordObjectiveProgressForActiveCharacter(
                player,
                target_type,
                target_key,
                amount,
                function(is_success, _, error)
                    if not is_success then
                        if error == "active-character-missing" then
                            Chat.SendMessage(player, "Aucun personnage actif.")
                            return
                        end

                        if error == "quest-objective-not-found" then
                            Chat.SendMessage(player, "Aucun objectif correspondant.")
                            return
                        end

                        if error == "objective-progress-amount-required" or error == "target-type-required" then
                            Chat.SendMessage(player, "Usage : /questprogress <target_type> <target_key> <amount>")
                            return
                        end

                        Chat.SendMessage(player, "Impossible d'enregistrer la progression d'objectif.")
                        return
                    end

                    Chat.SendMessage(player, "Progression objectif enregistree.")
                end
            )

            return false
        end
    end)
end

Console.Log("[gr_quests][server] Quests package loaded.")
Console.Log("[gr_quests][server] Quests bridge exported.")

Package.Require("../Shared/Index.lua")

local FactionRepository = Package.Require("FactionRepository.lua")
local FactionService = Package.Require("FactionService.lua")

GRFactions = GRFactions or {}
GRFactions.Server = GRFactions.Server or {}

local function resolve_database_service()
    if type(GRDatabaseBridge) == "table" and type(GRDatabaseBridge.GetService) == "function" then
        return GRDatabaseBridge.GetService()
    end

    return nil
end

local function callback_service_missing(callback)
    if type(callback) == "function" then
        callback(false, nil, "faction-service-missing")
    end

    return true
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

local function send_identity_messages(player, active_character, resolution)
    local first_name = trim_string(active_character and active_character.first_name) or "Unknown"
    local last_name = trim_string(active_character and active_character.last_name) or "Character"
    local faction_name = "Aucune"
    local rank_name = "Aucun"

    if type(resolution) == "table" then
        if type(resolution.faction) == "table" and trim_string(resolution.faction.name) ~= nil then
            faction_name = trim_string(resolution.faction.name)
        end

        if type(resolution.rank) == "table" and trim_string(resolution.rank.name) ~= nil then
            rank_name = trim_string(resolution.rank.name)
        end
    end

    Chat.SendMessage(player, "Identité RP :")
    Chat.SendMessage(player, string.format("Nom : %s %s", first_name, last_name))
    Chat.SendMessage(player, string.format("Faction : %s", faction_name))
    Chat.SendMessage(player, string.format("Grade : %s", rank_name))
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

local function send_faction_chat_feedback(player, message)
    Chat.SendMessage(player, message)
end

local function build_faction_chat_message(active_character, message)
    local first_name = trim_string(active_character and active_character.first_name) or "Unknown"
    local last_name = trim_string(active_character and active_character.last_name) or "Character"

    return string.format("[Faction] %s %s : %s", first_name, last_name, message)
end

local function get_active_character_from_bridge(player_or_platform_id)
    if GRCharactersBridge == nil or type(GRCharactersBridge.GetActiveCharacter) ~= "function" then
        return nil
    end

    return GRCharactersBridge.GetActiveCharacter(player_or_platform_id)
end

local function collect_faction_chat_recipients(sender_faction_id)
    local recipients = {}

    if type(Player) ~= "table" or type(Player.GetAll) ~= "function" then
        return recipients
    end

    for _, candidate_player in pairs(Player.GetAll()) do
        local candidate_platform_id = get_platform_id(candidate_player)
        local candidate_character = get_active_character_from_bridge(candidate_platform_id)

        if type(candidate_character) == "table" and tostring(candidate_character.faction_id) == tostring(sender_faction_id) then
            recipients[#recipients + 1] = candidate_player
        end
    end

    return recipients
end

local function handle_faction_chat_command(player, platform_id, payload)
    local active_character = nil
    local faction_id = nil
    local recipients = nil
    local formatted_message = nil

    if payload == nil then
        send_faction_chat_feedback(player, "Usage : /f <message>")
        Console.Log("[gr_factions][server] /f rejected reason=%s platform_id=%s.", "message-required", tostring(platform_id))
        return false
    end

    if GRCharactersBridge == nil or type(GRCharactersBridge.GetActiveCharacter) ~= "function" then
        send_faction_chat_feedback(player, "Aucun personnage actif.")
        Console.Log("[gr_factions][server] /f rejected reason=%s platform_id=%s.", "characters-bridge-unavailable", tostring(platform_id))
        return false
    end

    active_character = GRCharactersBridge.GetActiveCharacter(platform_id)

    if type(active_character) ~= "table" then
        send_faction_chat_feedback(player, "Aucun personnage actif.")
        Console.Log("[gr_factions][server] /f rejected reason=%s platform_id=%s.", "active-character-missing", tostring(platform_id))
        return false
    end

    faction_id = active_character.faction_id

    if faction_id == nil or tostring(faction_id) == "" then
        send_faction_chat_feedback(player, "Vous n'avez aucune faction.")
        Console.Log(
            "[gr_factions][server] /f rejected reason=%s platform_id=%s character_id=%s.",
            "faction-missing",
            tostring(platform_id),
            tostring(active_character.id)
        )
        return false
    end

    recipients = collect_faction_chat_recipients(faction_id)

    if #recipients < 1 then
        recipients[1] = player
    end

    formatted_message = build_faction_chat_message(active_character, payload)

    for _, recipient in ipairs(recipients) do
        Chat.SendMessage(recipient, formatted_message)
    end

    Console.Log(
        "[gr_factions][server] Faction chat sent faction_id=%s sender_character_id=%s recipients=%s.",
        tostring(faction_id),
        tostring(active_character.id),
        tostring(#recipients)
    )

    return false
end

local database_service = resolve_database_service()

GRFactions.Server.Repository = FactionRepository.Create(database_service)
GRFactions.Server.Service = FactionService.Create(GRFactions.Server.Repository)

if database_service ~= nil then
    Console.Log("[gr_factions][server] Database service resolved through GRDatabaseBridge.")
else
    Console.Log("[gr_factions][server] Database service unavailable because GRDatabaseBridge is missing.")
end

local GRFactionsBridge = {
    GetService = function()
        return GRFactions.Server.Service
    end,
    ListFactions = function(callback)
        if GRFactions.Server.Service == nil then
            return callback_service_missing(callback)
        end

        return GRFactions.Server.Service:ListFactions(callback)
    end,
    GetFactionById = function(faction_id, callback)
        if GRFactions.Server.Service == nil then
            return callback_service_missing(callback)
        end

        return GRFactions.Server.Service:GetFactionById(faction_id, callback)
    end,
    ListRanks = function(callback)
        if GRFactions.Server.Service == nil then
            return callback_service_missing(callback)
        end

        return GRFactions.Server.Service:ListRanks(callback)
    end,
    ListRanksByFactionId = function(faction_id, callback)
        if GRFactions.Server.Service == nil then
            return callback_service_missing(callback)
        end

        return GRFactions.Server.Service:ListRanksByFactionId(faction_id, callback)
    end,
    GetRankById = function(rank_id, callback)
        if GRFactions.Server.Service == nil then
            return callback_service_missing(callback)
        end

        return GRFactions.Server.Service:GetRankById(rank_id, callback)
    end,
    GetSpawnPointForFaction = function(faction_id, callback)
        if GRFactions.Server.Service == nil then
            return callback_service_missing(callback)
        end

        return GRFactions.Server.Service:GetSpawnPointForFaction(faction_id, callback)
    end,
    AssignCharacterFaction = function(character_id, faction_id, rank_id, callback)
        if GRFactions.Server.Service == nil then
            return callback_service_missing(callback)
        end

        return GRFactions.Server.Service:AssignCharacterFaction(character_id, faction_id, rank_id, callback)
    end,
    ResolveActiveCharacterFaction = function(player_or_platform_id, callback)
        if GRFactions.Server.Service == nil then
            return callback_service_missing(callback)
        end

        return GRFactions.Server.Service:ResolveActiveCharacterFaction(player_or_platform_id, callback)
    end,
    DebugLogActiveCharacterFaction = function(player_or_platform_id, callback)
        if GRFactions.Server.Service == nil then
            return callback_service_missing(callback)
        end

        return GRFactions.Server.Service:DebugLogActiveCharacterFaction(player_or_platform_id, callback)
    end,
}

Package.Export("GRFactionsBridge", GRFactionsBridge)

if type(Console) == "table" and type(Console.RegisterCommand) == "function" then
    Console.RegisterCommand("setfaction", function(character_id, faction_id, rank_id)
        local function normalize_assignment_value(raw_value)
            if type(raw_value) ~= "string" then
                return raw_value
            end

            local lowered_value = string.lower(raw_value)

            if lowered_value == "" or lowered_value == "nil" or lowered_value == "null" or lowered_value == "none" or lowered_value == "0" then
                return nil
            end

            return raw_value
        end

        if GRFactions.Server.Service == nil then
            Console.Log("[gr_factions][server] setfaction failed because faction service is unavailable.")
            return
        end

        GRFactions.Server.Service:AssignCharacterFaction(
            character_id,
            normalize_assignment_value(faction_id),
            normalize_assignment_value(rank_id),
            function(is_success, resolution, error)
                if not is_success then
                    Console.Log(
                        "[gr_factions][server] setfaction failed character_id=%s error=%s.",
                        tostring(character_id),
                        tostring(error)
                    )
                    return
                end

                Console.Log(
                    "[gr_factions][server] setfaction applied character_id=%s faction_id=%s rank_id=%s.",
                    tostring(resolution and resolution.character_id),
                    tostring(resolution and resolution.faction_id),
                    tostring(resolution and resolution.rank_id)
                )
            end
        )
    end, "assigns or clears a faction and rank on a character", { "character_id", "faction_id|nil", "rank_id|nil" })
end

if type(Chat) == "table" and type(Chat.Subscribe) == "function" and type(Chat.SendMessage) == "function" then
    Chat.Subscribe("PlayerSubmit", function(first_argument, second_argument)
        local player, message = normalize_chat_submit_arguments(first_argument, second_argument)
        local platform_id = nil
        local active_character = nil
        local command_name = nil
        local command_payload = nil

        if player == nil then
            return
        end

        command_name, command_payload = get_chat_command(message)

        if command_name == "f" then
            platform_id = get_platform_id(player)

            if platform_id == nil then
                Chat.SendMessage(player, "Aucun personnage actif.")
                Console.Log("[gr_factions][server] /f rejected reason=%s.", "platform-id-required")
                return false
            end

            return handle_faction_chat_command(player, platform_id, command_payload)
        end

        if trim_string(message) ~= "/whoami" then
            return
        end

        platform_id = get_platform_id(player)

        if platform_id == nil then
            Chat.SendMessage(player, "Aucun personnage actif.")
            Console.Log("[gr_factions][server] /whoami rejected reason=%s.", "platform-id-required")
            return false
        end

        if GRCharactersBridge == nil or type(GRCharactersBridge.GetActiveCharacter) ~= "function" then
            Chat.SendMessage(player, "Aucun personnage actif.")
            Console.Log("[gr_factions][server] /whoami rejected reason=%s.", "characters-bridge-unavailable")
            return false
        end

        active_character = GRCharactersBridge.GetActiveCharacter(platform_id)

        if type(active_character) ~= "table" then
            Chat.SendMessage(player, "Aucun personnage actif.")
            Console.Log("[gr_factions][server] /whoami rejected reason=%s platform_id=%s.", "active-character-missing", tostring(platform_id))
            return false
        end

        if GRFactions.Server.Service == nil then
            Chat.SendMessage(player, "Faction : Aucune")
            Chat.SendMessage(player, "Grade : Aucun")
            Console.Log("[gr_factions][server] /whoami rejected reason=%s platform_id=%s.", "faction-service-missing", tostring(platform_id))
            return false
        end

        GRFactions.Server.Service:ResolveActiveCharacterFaction(platform_id, function(is_success, resolution, error)
            if not is_success then
                Chat.SendMessage(player, "Identité RP :")
                Chat.SendMessage(player, string.format(
                    "Nom : %s %s",
                    trim_string(active_character.first_name) or "Unknown",
                    trim_string(active_character.last_name) or "Character"
                ))
                Chat.SendMessage(player, "Faction : Aucune")
                Chat.SendMessage(player, "Grade : Aucun")
                Console.Log(
                    "[gr_factions][server] /whoami fallback platform_id=%s error=%s.",
                    tostring(platform_id),
                    tostring(error)
                )
                return
            end

            send_identity_messages(player, active_character, resolution)
            Console.Log(
                "[gr_factions][server] /whoami resolved platform_id=%s character_id=%s.",
                tostring(platform_id),
                tostring(active_character.id)
            )
        end)

        return false
    end)
end

Console.Log("[gr_factions][server] Factions package loaded.")
Console.Log("[gr_factions][server] Factions bridge exported.")

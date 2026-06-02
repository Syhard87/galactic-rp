Package.Require("../Shared/Index.lua")

local ReputationRepository = Package.Require("ReputationRepository.lua")
local ReputationService = Package.Require("ReputationService.lua")

GRReputation = GRReputation or {}
GRReputation.Server = GRReputation.Server or {}

local function resolve_database_service()
    if type(GRDatabaseBridge) == "table" and type(GRDatabaseBridge.GetService) == "function" then
        return GRDatabaseBridge.GetService()
    end

    return nil
end

local function callback_service_missing(callback)
    if type(callback) == "function" then
        callback(false, nil, "reputation-service-missing")
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

local function normalize_integer(value)
    if type(value) == "number" then
        if value % 1 ~= 0 then
            return nil
        end

        return math.floor(value)
    end

    if type(value) == "string" and value:match("^[+-]?%d+$") ~= nil then
        local parsed_value = tonumber(value)

        if parsed_value ~= nil then
            return math.floor(parsed_value)
        end
    end

    return nil
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

local function can_use_reputation_debug_commands(player_or_platform_id)
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

    debug_commands_enabled = normalize_boolean(custom_settings.gr_reputation_debug_commands_enabled, false)

    if not debug_commands_enabled then
        return false, platform_id, "debug-disabled"
    end

    allowlist, has_allowlist_entries = parse_platform_id_allowlist(custom_settings.gr_reputation_debug_allowed_platform_ids)

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

local function resolve_active_character_id(player_or_platform_id)
    local active_character = nil

    if type(GRCharactersBridge) ~= "table" or type(GRCharactersBridge.GetActiveCharacter) ~= "function" then
        return nil
    end

    active_character = GRCharactersBridge.GetActiveCharacter(player_or_platform_id)

    if type(active_character) ~= "table" or active_character.id == nil then
        return nil
    end

    return active_character.id
end

local database_service = resolve_database_service()

GRReputation.Server.Repository = ReputationRepository.Create(database_service)
GRReputation.Server.Service = ReputationService.Create(GRReputation.Server.Repository)

if database_service ~= nil then
    Console.Log("[gr_reputation][server] Database service resolved through GRDatabaseBridge.")
else
    Console.Log("[gr_reputation][server] Database service unavailable because GRDatabaseBridge is missing.")
end

GRReputationBridge = GRReputationBridge or {}

GRReputationBridge.GetService = function()
    return GRReputation.Server.Service
end

GRReputationBridge.AddReputation = function(character_id, reputation_key, amount, reason, callback)
    if GRReputation.Server.Service == nil then
        return callback_service_missing(callback)
    end

    return GRReputation.Server.Service:AddReputation(character_id, reputation_key, amount, reason, callback)
end

GRReputationBridge.SetReputation = function(character_id, reputation_key, value, reason, callback)
    if GRReputation.Server.Service == nil then
        return callback_service_missing(callback)
    end

    return GRReputation.Server.Service:SetReputation(character_id, reputation_key, value, reason, callback)
end

GRReputationBridge.ListCharacterReputations = function(character_id, callback)
    if GRReputation.Server.Service == nil then
        return callback_service_missing(callback)
    end

    return GRReputation.Server.Service:ListCharacterReputations(character_id, callback)
end

Package.Export("GRReputationBridge", GRReputationBridge)

if type(Chat) == "table" and type(Chat.Subscribe) == "function" and type(Chat.SendMessage) == "function" then
    Chat.Subscribe("PlayerSubmit", function(first_argument, second_argument)
        local player, message = normalize_chat_submit_arguments(first_argument, second_argument)
        local command_name = nil
        local payload = nil

        if player == nil then
            return
        end

        command_name, payload = get_chat_command(message)

        if command_name ~= "reputations" and command_name ~= "givereputation" then
            return
        end

        local is_allowed = false
        local platform_id = nil
        local guard_error = nil

        is_allowed, platform_id, guard_error = can_use_reputation_debug_commands(player)

        if not is_allowed then
            Console.Log(
                "[gr_reputation][server] Reputation debug command denied platform_id=%s reason=%s.",
                tostring(platform_id),
                tostring(guard_error)
            )
            Chat.SendMessage(player, "Commande reputation desactivee.")
            return false
        end

        local active_character_id = resolve_active_character_id(player)

        if active_character_id == nil then
            Chat.SendMessage(player, "Personnage actif introuvable.")
            return false
        end

        if command_name == "reputations" then
            GRReputation.Server.Service:ListCharacterReputations(active_character_id, function(is_success, reputation_rows, error)
                if not is_success then
                    Chat.SendMessage(player, "Reputations indisponibles.")
                    return
                end

                if type(reputation_rows) ~= "table" or #reputation_rows == 0 then
                    Chat.SendMessage(player, "Reputations :")
                    Chat.SendMessage(player, "- aucune")
                    return
                end

                Chat.SendMessage(player, "Reputations :")

                for _, reputation_row in ipairs(reputation_rows) do
                    Chat.SendMessage(
                        player,
                        string.format(
                            "- %s : %s %s",
                            tostring(reputation_row.reputation_key),
                            tostring(reputation_row.value),
                            tostring(reputation_row.rank)
                        )
                    )
                end
            end)

            return false
        end

        if payload == nil then
            Chat.SendMessage(player, "Usage : /givereputation <reputation_key> <amount> [reason]")
            return false
        end

        local reputation_key, amount_text, reason = payload:match("^(%S+)%s+([+-]?%d+)%s*(.*)$")
        local amount = normalize_integer(amount_text)
        local normalized_reason = trim_string(reason) or "debug-command"

        reputation_key = normalize_reputation_key(reputation_key)

        if reputation_key == nil then
            Chat.SendMessage(player, "Usage : /givereputation <reputation_key> <amount> [reason]")
            return false
        end

        if amount == nil or amount == 0 or math.abs(amount) > 1000 then
            Chat.SendMessage(player, "Montant invalide.")
            return false
        end

        GRReputation.Server.Service:AddReputation(active_character_id, reputation_key, amount, normalized_reason, function(is_success, result, error)
            if not is_success then
                if error == "reputation-not-found" or error == "reputation-key-required" then
                    Chat.SendMessage(player, string.format("Reputation inconnue : %s", tostring(reputation_key)))
                    return
                end

                if error == "reputation-amount-required" then
                    Chat.SendMessage(player, "Montant invalide.")
                    return
                end

                Chat.SendMessage(player, "Impossible de modifier la reputation.")
                return
            end

            Chat.SendMessage(
                player,
                string.format(
                    "Reputation modifiee : %s %s => %s %s",
                    tostring(result.reputation_key),
                    tostring(amount > 0 and ("+" .. tostring(amount)) or tostring(amount)),
                    tostring(result.value),
                    tostring(result.rank)
                )
            )
        end)

        return false
    end)
end

Console.Log("[gr_reputation][server] Reputation package loaded.")
Console.Log("[gr_reputation][server] Reputation bridge exported.")

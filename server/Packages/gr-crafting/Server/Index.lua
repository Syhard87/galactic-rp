Package.Require("../Shared/Index.lua")

local CraftingRepository = Package.Require("CraftingRepository.lua")
local CraftingService = Package.Require("CraftingService.lua")

GRCrafting = GRCrafting or {}
GRCrafting.Server = GRCrafting.Server or {}

local function resolve_database_service()
    if type(GRDatabaseBridge) == "table" and type(GRDatabaseBridge.GetService) == "function" then
        return GRDatabaseBridge.GetService()
    end

    return nil
end

local function callback_service_missing(callback)
    if type(callback) == "function" then
        callback(false, nil, "crafting-service-missing")
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

local function can_use_crafting_debug_commands(player_or_platform_id)
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

    debug_commands_enabled = normalize_boolean(custom_settings.gr_crafting_debug_commands_enabled, false)

    if not debug_commands_enabled then
        return false, platform_id, "debug-disabled"
    end

    allowlist, has_allowlist_entries = parse_platform_id_allowlist(custom_settings.gr_crafting_debug_allowed_platform_ids)

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

GRCrafting.Server.Repository = CraftingRepository.Create(database_service)
GRCrafting.Server.Service = CraftingService.Create(GRCrafting.Server.Repository)

if database_service ~= nil then
    Console.Log("[gr_crafting][server] Database service resolved through GRDatabaseBridge.")
else
    Console.Log("[gr_crafting][server] Database service unavailable because GRDatabaseBridge is missing.")
end

local GRCraftingBridge = {
    GetService = function()
        return GRCrafting.Server.Service
    end,
    ListActiveRecipes = function(callback)
        if GRCrafting.Server.Service == nil then
            return callback_service_missing(callback)
        end

        return GRCrafting.Server.Service:ListActiveRecipes(callback)
    end,
    ListActiveStations = function(callback)
        if GRCrafting.Server.Service == nil then
            return callback_service_missing(callback)
        end

        return GRCrafting.Server.Service:ListActiveStations(callback)
    end,
    CraftItem = function(character_id, recipe_key, callback)
        if GRCrafting.Server.Service == nil then
            return callback_service_missing(callback)
        end

        return GRCrafting.Server.Service:CraftItem(character_id, recipe_key, callback)
    end,
    CraftItemForActiveCharacter = function(player_or_platform_id, recipe_key, callback)
        if GRCrafting.Server.Service == nil then
            return callback_service_missing(callback)
        end

        return GRCrafting.Server.Service:CraftItemForActiveCharacter(player_or_platform_id, recipe_key, callback)
    end,
}

Package.Export("GRCraftingBridge", GRCraftingBridge)

if type(Chat) == "table" and type(Chat.Subscribe) == "function" and type(Chat.SendMessage) == "function" then
    Chat.Subscribe("PlayerSubmit", function(first_argument, second_argument)
        local player, message = normalize_chat_submit_arguments(first_argument, second_argument)
        local command_name = nil
        local payload = nil

        if player == nil then
            return
        end

        command_name, payload = get_chat_command(message)

        if command_name ~= "craft" and command_name ~= "craftstations" then
            return
        end

        local is_allowed = false
        local platform_id = nil
        local guard_error = nil

        is_allowed, platform_id, guard_error = can_use_crafting_debug_commands(player)

        if not is_allowed then
            Console.Log(
                "[gr_crafting][server] Craft debug command denied platform_id=%s reason=%s.",
                tostring(platform_id),
                tostring(guard_error)
            )
            Chat.SendMessage(player, "Commande reservee au staff/dev.")
            return false
        end

        if command_name == "craftstations" then
            GRCrafting.Server.Service:ListActiveStations(function(is_success, station_rows, error)
                if not is_success then
                    Chat.SendMessage(player, "Stations de craft indisponibles.")
                    return
                end

                if type(station_rows) ~= "table" or #station_rows == 0 then
                    Chat.SendMessage(player, "Aucune station de craft active.")
                    return
                end

                Chat.SendMessage(player, "Stations de craft :")

                for _, station_row in ipairs(station_rows) do
                    Chat.SendMessage(
                        player,
                        string.format(
                            "- %s | type=%s | pos=%s,%s,%s | radius=%s",
                            tostring(station_row.key),
                            tostring(station_row.station_type),
                            tostring(station_row.position_x),
                            tostring(station_row.position_y),
                            tostring(station_row.position_z),
                            tostring(station_row.radius)
                        )
                    )
                end
            end)

            return false
        end

        if payload == nil then
            Chat.SendMessage(player, "Usage : /craft <recipe_key>")
            return false
        end

        GRCrafting.Server.Service:CraftItemForActiveCharacter(player, payload, function(is_success, result, error)
            if not is_success then
                if error == "active-character-missing" then
                    Chat.SendMessage(player, "Craft impossible : personnage actif introuvable")
                    return
                end

                if error == "recipe-not-found" or error == "recipe-key-required" then
                    Chat.SendMessage(player, "Craft impossible : recette inconnue")
                    return
                end

                if error == "ingredients-insufficient" then
                    Chat.SendMessage(player, "Craft impossible : ingredients insuffisants")
                    return
                end

                if error == "required-skill-level-insufficient" then
                    Chat.SendMessage(player, "Craft impossible : niveau de competence insuffisant")
                    return
                end

                if error == "required-station-not-found" then
                    Chat.SendMessage(player, "Craft impossible : station requise introuvable")
                    return
                end

                if error == "required-station-inactive" then
                    Chat.SendMessage(player, "Craft impossible : station inactive")
                    return
                end

                if error == "required-station-too-far" then
                    Chat.SendMessage(player, "Craft impossible : vous etes trop loin de la station")
                    return
                end

                Chat.SendMessage(player, "Craft impossible")
                return
            end

            Chat.SendMessage(
                player,
                string.format(
                    "Craft reussi : %s x%s",
                    tostring(result.result_item_key),
                    tostring(result.result_quantity)
                )
            )

            if result.reward_skill_key ~= nil and result.reward_skill_xp ~= nil and result.reward_skill_xp > 0 then
                Chat.SendMessage(
                    player,
                    string.format(
                        "XP competence gagnee : %s x%s",
                        tostring(result.reward_skill_key),
                        tostring(result.reward_skill_xp)
                    )
                )
            end
        end)

        return false
    end)
end

Console.Log("[gr_crafting][server] Crafting package loaded.")
Console.Log("[gr_crafting][server] Crafting bridge exported.")

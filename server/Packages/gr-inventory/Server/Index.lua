Package.Require("../Shared/Index.lua")

local InventoryRepository = Package.Require("InventoryRepository.lua")
local InventoryService = Package.Require("InventoryService.lua")

GRInventory = GRInventory or {}
GRInventory.Server = GRInventory.Server or {}

local function resolve_database_service()
    if type(GRDatabaseBridge) == "table" and type(GRDatabaseBridge.GetService) == "function" then
        return GRDatabaseBridge.GetService()
    end

    return nil
end

local function callback_service_missing(callback)
    if type(callback) == "function" then
        callback(false, nil, "inventory-service-missing")
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

local function normalize_quantity(value)
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

local function can_use_giveitem_command(player_or_platform_id)
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

    debug_commands_enabled = normalize_boolean(custom_settings.gr_inventory_debug_commands_enabled, false)

    if not debug_commands_enabled then
        return false, platform_id, "debug-disabled"
    end

    allowlist, has_allowlist_entries = parse_platform_id_allowlist(custom_settings.gr_inventory_debug_allowed_platform_ids)

    if not has_allowlist_entries then
        return false, platform_id, "allowlist-missing"
    end

    if allowlist[platform_id] ~= true then
        return false, platform_id, "not-authorized"
    end

    return true, platform_id, nil
end

local function summarize_inventory_rows(rows)
    local summary_by_item_key = {}
    local ordered_item_keys = {}
    local lines = {}

    for _, inventory_row in ipairs(rows or {}) do
        local item_key = tostring(inventory_row.item_key)
        local item_name = trim_string(inventory_row.item_name) or item_key

        if summary_by_item_key[item_key] == nil then
            summary_by_item_key[item_key] = {
                item_name = item_name,
                quantity = 0,
            }

            ordered_item_keys[#ordered_item_keys + 1] = item_key
        end

        summary_by_item_key[item_key].quantity = summary_by_item_key[item_key].quantity + (inventory_row.quantity or 0)
    end

    for _, item_key in ipairs(ordered_item_keys) do
        local summary = summary_by_item_key[item_key]
        lines[#lines + 1] = string.format("- %s x%s", tostring(summary.item_name), tostring(summary.quantity))
    end

    return lines
end

local function is_usable_item(item_key)
    return item_key == "medkit_basic"
end

local database_service = resolve_database_service()

GRInventory.Server.Repository = InventoryRepository.Create(database_service)
GRInventory.Server.Service = InventoryService.Create(GRInventory.Server.Repository)

if database_service ~= nil then
    Console.Log("[gr_inventory][server] Database service resolved through GRDatabaseBridge.")
else
    Console.Log("[gr_inventory][server] Database service unavailable because GRDatabaseBridge is missing.")
end

local GRInventoryBridge = {
    GetService = function()
        return GRInventory.Server.Service
    end,
    ListInventory = function(character_id, callback)
        if GRInventory.Server.Service == nil then
            return callback_service_missing(callback)
        end

        return GRInventory.Server.Service:ListInventory(character_id, callback)
    end,
    ListActiveCharacterInventory = function(player_or_platform_id, callback)
        if GRInventory.Server.Service == nil then
            return callback_service_missing(callback)
        end

        return GRInventory.Server.Service:ListActiveCharacterInventory(player_or_platform_id, callback)
    end,
    AddItem = function(character_id, item_key, quantity, metadata_json, callback)
        if GRInventory.Server.Service == nil then
            return callback_service_missing(callback)
        end

        return GRInventory.Server.Service:AddItem(character_id, item_key, quantity, metadata_json, callback)
    end,
    AddItemToActiveCharacter = function(player_or_platform_id, item_key, quantity, metadata_json, callback)
        if GRInventory.Server.Service == nil then
            return callback_service_missing(callback)
        end

        return GRInventory.Server.Service:AddItemToActiveCharacter(
            player_or_platform_id,
            item_key,
            quantity,
            metadata_json,
            callback
        )
    end,
    RemoveItem = function(character_id, item_key, quantity, callback)
        if GRInventory.Server.Service == nil then
            return callback_service_missing(callback)
        end

        return GRInventory.Server.Service:RemoveItem(character_id, item_key, quantity, callback)
    end,
    RemoveItemFromActiveCharacter = function(player_or_platform_id, item_key, quantity, callback)
        if GRInventory.Server.Service == nil then
            return callback_service_missing(callback)
        end

        return GRInventory.Server.Service:RemoveItemFromActiveCharacter(player_or_platform_id, item_key, quantity, callback)
    end,
}

Package.Export("GRInventoryBridge", GRInventoryBridge)

if type(Chat) == "table" and type(Chat.Subscribe) == "function" and type(Chat.SendMessage) == "function" then
    Chat.Subscribe("PlayerSubmit", function(first_argument, second_argument)
        local player, message = normalize_chat_submit_arguments(first_argument, second_argument)
        local command_name = nil
        local payload = nil

        if player == nil then
            return
        end

        command_name, payload = get_chat_command(message)

        if command_name == "inv" then
            GRInventory.Server.Service:ListActiveCharacterInventory(player, function(is_success, inventory_rows, error)
                local lines = nil

                if not is_success then
                    if error == "active-character-missing" then
                        Chat.SendMessage(player, "Aucun personnage actif.")
                        return
                    end

                    Chat.SendMessage(player, "Inventaire indisponible.")
                    return
                end

                lines = summarize_inventory_rows(inventory_rows)

                if #lines == 0 then
                    Chat.SendMessage(player, "Inventaire vide.")
                    return
                end

                Chat.SendMessage(player, "Inventaire :")

                for _, line in ipairs(lines) do
                    Chat.SendMessage(player, line)
                end
            end)

            return false
        end

        if command_name == "giveitem" then
            local is_allowed = false
            local platform_id = nil
            local guard_error = nil
            local item_key = nil
            local quantity_text = nil
            local quantity = nil

            is_allowed, platform_id, guard_error = can_use_giveitem_command(player)

            if not is_allowed then
                Console.Log(
                    "[gr_inventory][server] Give item command denied platform_id=%s reason=%s.",
                    tostring(platform_id),
                    tostring(guard_error)
                )
                Chat.SendMessage(player, "Commande reservee au staff/dev.")
                return false
            end

            if payload == nil then
                Chat.SendMessage(player, "Usage : /giveitem <item_key> <quantity>")
                return false
            end

            item_key, quantity_text = payload:match("^(%S+)%s+(%S+)$")
            quantity = normalize_quantity(quantity_text)

            if trim_string(item_key) == nil or quantity == nil then
                Chat.SendMessage(player, "Usage : /giveitem <item_key> <quantity>")
                return false
            end

            GRInventory.Server.Service:AddItemToActiveCharacter(player, item_key, quantity, nil, function(is_success, result, error)
                if not is_success then
                    if error == "active-character-missing" then
                        Chat.SendMessage(player, "Aucun personnage actif.")
                        return
                    end

                    if error == "item-not-found" then
                        Chat.SendMessage(player, "Objet inconnu.")
                        return
                    end

                    if error == "quantity-required" or error == "item-key-required" then
                        Chat.SendMessage(player, "Usage : /giveitem <item_key> <quantity>")
                        return
                    end

                    Chat.SendMessage(player, "Ajout d'objet impossible.")
                    return
                end

                Chat.SendMessage(
                    player,
                    string.format("Objet ajoute : %s x%s", tostring(result.item_key), tostring(result.quantity))
                )
            end)

            return false
        end

        if command_name == "dropitem" then
            local item_key = nil
            local quantity_text = nil
            local quantity = nil

            if payload == nil then
                Chat.SendMessage(player, "Usage : /dropitem <item_key> <quantity>")
                return false
            end

            item_key, quantity_text = payload:match("^(%S+)%s+(%S+)$")
            quantity = normalize_quantity(quantity_text)

            if trim_string(item_key) == nil or quantity == nil then
                Chat.SendMessage(player, "Usage : /dropitem <item_key> <quantity>")
                return false
            end

            GRInventory.Server.Service:RemoveItemFromActiveCharacter(player, item_key, quantity, function(is_success, result, error)
                if not is_success then
                    if error == "active-character-missing" then
                        Chat.SendMessage(player, "Aucun personnage actif.")
                        return
                    end

                    if error == "inventory-item-quantity-insufficient" then
                        Chat.SendMessage(player, "Quantite insuffisante.")
                        return
                    end

                    if error == "quantity-required" or error == "item-key-required" then
                        Chat.SendMessage(player, "Usage : /dropitem <item_key> <quantity>")
                        return
                    end

                    Chat.SendMessage(player, "Impossible de retirer l'objet.")
                    return
                end

                Chat.SendMessage(
                    player,
                    string.format("Objet retire : %s x%s", tostring(result.item_key), tostring(result.quantity))
                )
            end)

            return false
        end

        if command_name == "useitem" then
            local item_key = trim_string(payload)

            if item_key == nil or item_key:find("%s") ~= nil then
                Chat.SendMessage(player, "Usage : /useitem <item_key>")
                return false
            end

            if not is_usable_item(item_key) then
                Chat.SendMessage(player, "Objet non utilisable.")
                return false
            end

            GRInventory.Server.Service:RemoveItemFromActiveCharacter(player, item_key, 1, function(is_success, result, error)
                if not is_success then
                    if error == "active-character-missing" then
                        Chat.SendMessage(player, "Aucun personnage actif.")
                        return
                    end

                    if error == "inventory-item-quantity-insufficient" then
                        Chat.SendMessage(player, "Objet indisponible.")
                        return
                    end

                    Chat.SendMessage(player, "Impossible de retirer l'objet.")
                    return
                end

                Chat.SendMessage(
                    player,
                    string.format("Objet utilise : %s", tostring(result.item_key))
                )
            end)

            return false
        end
    end)
end

Console.Log("[gr_inventory][server] Inventory package loaded.")
Console.Log("[gr_inventory][server] Inventory bridge exported.")

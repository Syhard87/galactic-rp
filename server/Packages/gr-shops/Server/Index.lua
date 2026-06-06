Package.Require("../Shared/Index.lua")

local ShopRepository = Package.Require("ShopRepository.lua")
local ShopService = Package.Require("ShopService.lua")

GRShops = GRShops or {}
GRShops.Server = GRShops.Server or {}

local function resolve_database_service()
    if type(GRDatabaseBridge) == "table" and type(GRDatabaseBridge.GetService) == "function" then
        return GRDatabaseBridge.GetService()
    end

    return nil
end

local function callback_service_missing(callback)
    if type(callback) == "function" then
        callback(false, nil, "shops-service-missing")
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

local function can_use_shops_debug_commands(player_or_platform_id)
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

    debug_commands_enabled = normalize_boolean(custom_settings.gr_shops_debug_commands_enabled, false)

    if not debug_commands_enabled then
        return false, platform_id, "debug-disabled"
    end

    allowlist, has_allowlist_entries = parse_platform_id_allowlist(custom_settings.gr_shops_debug_allowed_platform_ids)

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

local function build_shop_line(shop_row)
    return string.format(
        "- %s : %s",
        tostring(shop_row.key),
        tostring(shop_row.name or shop_row.key)
    )
end

local function build_shop_item_line(shop_item_row)
    return string.format(
        "- %s price=%s sell_price=%s wallet=%s sellable=%s active=%s",
        tostring(shop_item_row.item_key),
        tostring(shop_item_row.price),
        tostring(shop_item_row.sell_price),
        tostring(shop_item_row.wallet),
        tostring(shop_item_row.is_sellable),
        tostring(shop_item_row.is_active)
    )
end

local database_service = resolve_database_service()

GRShops.Server.Repository = ShopRepository.Create(database_service)
GRShops.Server.Service = ShopService.Create(GRShops.Server.Repository)

GRShopsBridge = GRShopsBridge or {}

GRShopsBridge.GetService = function()
    return GRShops.Server.Service
end

GRShopsBridge.ListShops = function(callback)
    if GRShops.Server.Service == nil then
        return callback_service_missing(callback)
    end

    return GRShops.Server.Service:ListShops(callback)
end

GRShopsBridge.ListShopItems = function(shop_key, callback)
    if GRShops.Server.Service == nil then
        return callback_service_missing(callback)
    end

    return GRShops.Server.Service:ListShopItems(shop_key, callback)
end

GRShopsBridge.BuyItem = function(character_id, shop_key, item_key, quantity, callback)
    if GRShops.Server.Service == nil then
        return callback_service_missing(callback)
    end

    return GRShops.Server.Service:BuyItem(character_id, shop_key, item_key, quantity, callback)
end

GRShopsBridge.SellItem = function(character_id, shop_key, item_key, quantity, callback)
    if GRShops.Server.Service == nil then
        return callback_service_missing(callback)
    end

    return GRShops.Server.Service:SellItem(character_id, shop_key, item_key, quantity, callback)
end

Package.Export("GRShopsBridge", GRShopsBridge)

if type(Chat) == "table" and type(Chat.Subscribe) == "function" and type(Chat.SendMessage) == "function" then
    Chat.Subscribe("PlayerSubmit", function(first_argument, second_argument)
        local player, message = normalize_chat_submit_arguments(first_argument, second_argument)
        local command_name = nil
        local payload = nil

        if player == nil then
            return
        end

        command_name, payload = get_chat_command(message)

        if command_name ~= "shops"
            and command_name ~= "shopitems"
            and command_name ~= "buy"
            and command_name ~= "sell"
        then
            return
        end

        local is_allowed = false
        local platform_id = nil
        local guard_error = nil

        is_allowed, platform_id, guard_error = can_use_shops_debug_commands(player)

        if not is_allowed then
            Console.Log(
                "[gr_shops][server] Shop debug command denied platform_id=%s reason=%s.",
                tostring(platform_id),
                tostring(guard_error)
            )
            Chat.SendMessage(player, "Commande boutique desactivee.")
            return false
        end

        if command_name == "shops" then
            GRShops.Server.Service:ListShops(function(is_success, shop_rows, error)
                if not is_success then
                    Chat.SendMessage(player, "Boutiques indisponibles.")
                    return
                end

                if type(shop_rows) ~= "table" or #shop_rows == 0 then
                    Chat.SendMessage(player, "Boutiques disponibles :")
                    Chat.SendMessage(player, "- aucune")
                    return
                end

                Chat.SendMessage(player, "Boutiques disponibles :")

                for _, shop_row in ipairs(shop_rows) do
                    Chat.SendMessage(player, build_shop_line(shop_row))
                end
            end)

            return false
        end

        if command_name == "shopitems" then
            if payload == nil then
                Chat.SendMessage(player, "Usage : /shopitems <shop_key>")
                return false
            end

            GRShops.Server.Service:ListShopItems(payload, function(is_success, shop_item_rows, error)
                if not is_success then
                    if error == "shop-key-required" then
                        Chat.SendMessage(player, "Usage : /shopitems <shop_key>")
                        return
                    end

                    if error == "shop-not-found" then
                        Chat.SendMessage(player, "Boutique introuvable.")
                        return
                    end

                    Chat.SendMessage(player, "Boutiques indisponibles.")
                    return
                end

                Chat.SendMessage(player, string.format("Objets %s :", tostring(payload)))

                if type(shop_item_rows) ~= "table" or #shop_item_rows == 0 then
                    Chat.SendMessage(player, "- aucune")
                    return
                end

                for _, shop_item_row in ipairs(shop_item_rows) do
                    Chat.SendMessage(player, build_shop_item_line(shop_item_row))
                end
            end)

            return false
        end

        local active_character_id = resolve_active_character_id(player)

        if active_character_id == nil then
            Chat.SendMessage(player, "Personnage actif introuvable.")
            return false
        end

        if payload == nil then
            if command_name == "buy" then
                Chat.SendMessage(player, "Usage : /buy <shop_key> <item_key> <quantity>")
                return false
            end

            Chat.SendMessage(player, "Usage : /sell <shop_key> <item_key> <quantity>")
            return false
        end

        local shop_key, item_key, quantity_text = payload:match("^(%S+)%s+(%S+)%s+(%S+)$")
        local quantity = normalize_positive_integer(quantity_text)

        if trim_string(shop_key) == nil or trim_string(item_key) == nil or quantity_text == nil then
            if command_name == "buy" then
                Chat.SendMessage(player, "Usage : /buy <shop_key> <item_key> <quantity>")
                return false
            end

            Chat.SendMessage(player, "Usage : /sell <shop_key> <item_key> <quantity>")
            return false
        end

        if quantity == nil then
            Chat.SendMessage(player, "Quantite invalide.")
            return false
        end

        if command_name == "sell" then
            GRShops.Server.Service:SellItem(active_character_id, shop_key, item_key, quantity, function(is_success, result, error)
                if not is_success then
                    if error == "shop-not-found" then
                        Chat.SendMessage(player, "Boutique introuvable.")
                        return
                    end

                    if error == "shop-inactive" then
                        Chat.SendMessage(player, "Boutique inactive.")
                        return
                    end

                    if error == "shop-item-not-found"
                        or error == "shop-item-inactive"
                        or error == "shop-item-not-sellable"
                        or error == "sell-price-invalid"
                    then
                        Chat.SendMessage(player, "Objet non revendable dans cette boutique.")
                        return
                    end

                    if error == "quantity-invalid" then
                        Chat.SendMessage(player, "Quantite invalide.")
                        return
                    end

                    if error == "inventory-item-quantity-insufficient" then
                        Chat.SendMessage(player, "Inventaire insuffisant.")
                        return
                    end

                    if error == "inventory-unavailable" then
                        Chat.SendMessage(player, "Inventaire indisponible.")
                        return
                    end

                    if error == "economy-unavailable" then
                        Chat.SendMessage(player, "Economie indisponible.")
                        return
                    end

                    if error == "economy-credit-failed" or error == "rollback-failed" then
                        Chat.SendMessage(player, "Erreur lors de la vente.")
                        return
                    end

                    Chat.SendMessage(player, "Erreur lors de la vente.")
                    return
                end

                Chat.SendMessage(
                    player,
                    string.format(
                        "Vente effectuee : %s x%s pour %s credits.",
                        tostring(item_key),
                        tostring(quantity),
                        tostring(result and result.total_price or 0)
                    )
                )
            end)

            return false
        end

        GRShops.Server.Service:BuyItem(active_character_id, shop_key, item_key, quantity, function(is_success, result, error)
            if not is_success then
                if error == "shop-not-found" then
                    Chat.SendMessage(player, "Boutique introuvable.")
                    return
                end

                if error == "shop-inactive" then
                    Chat.SendMessage(player, "Boutique inactive.")
                    return
                end

                if error == "shop-item-not-found" or error == "shop-item-inactive" then
                    Chat.SendMessage(player, "Objet indisponible dans cette boutique.")
                    return
                end

                if error == "quantity-invalid" then
                    Chat.SendMessage(player, "Quantite invalide.")
                    return
                end

                if error == "insufficient-funds" then
                    Chat.SendMessage(player, "Solde insuffisant.")
                    return
                end

                if error == "inventory-unavailable" then
                    Chat.SendMessage(player, "Inventaire indisponible.")
                    return
                end

                if error == "economy-unavailable" then
                    Chat.SendMessage(player, "Economie indisponible.")
                    return
                end

                if error == "inventory-add-failed" or error == "rollback-failed" then
                    Chat.SendMessage(player, "Erreur lors de l'achat.")
                    return
                end

                Chat.SendMessage(player, "Erreur lors de l'achat.")
                return
            end

            Chat.SendMessage(
                player,
                string.format(
                    "Achat effectue : %s x%s pour %s credits.",
                    tostring(item_key),
                    tostring(quantity),
                    tostring(result and result.total_price or 0)
                )
            )
        end)

        return false
    end)
end

Console.Log("[gr_shops][server] Shops package loaded.")
Console.Log("[gr_shops][server] Shops bridge exported.")

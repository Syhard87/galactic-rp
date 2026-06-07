Package.Require("../Shared/Index.lua")

local GatheringRepository = Package.Require("GatheringRepository.lua")
local GatheringService = Package.Require("GatheringService.lua")

GRGathering = GRGathering or {}
GRGathering.Server = GRGathering.Server or {}

local function resolve_database_service()
    if type(GRDatabaseBridge) == "table" and type(GRDatabaseBridge.GetService) == "function" then
        return GRDatabaseBridge.GetService()
    end

    return nil
end

local function callback_service_missing(callback)
    if type(callback) == "function" then
        callback(false, nil, "gathering-service-missing")
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

local function can_use_gathering_debug_commands(player_or_platform_id)
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

    debug_commands_enabled = normalize_boolean(custom_settings.gr_gathering_debug_commands_enabled, false)

    if not debug_commands_enabled then
        return false, platform_id, "debug-disabled"
    end

    allowlist, has_allowlist_entries = parse_platform_id_allowlist(custom_settings.gr_gathering_debug_allowed_platform_ids)

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

local function build_stock_text(node_row)
    if type(node_row) ~= "table" or node_row.stock_enabled ~= true then
        return "illimite"
    end

    return string.format(
        "%s/%s",
        tostring(node_row.stock_quantity),
        tostring(node_row.max_stock)
    )
end

local function build_restock_text(node_row)
    if type(node_row) ~= "table" or node_row.stock_enabled ~= true then
        return "none"
    end

    if node_row.restock_seconds == nil then
        return "none"
    end

    return string.format("%ss", tostring(node_row.restock_seconds))
end

local function get_node_row(node_info)
    if type(node_info) ~= "table" then
        return {}
    end

    if type(node_info.node) == "table" then
        return node_info.node
    end

    return node_info
end

local function format_chance_percent(value)
    local numeric_value = tonumber(value)

    if numeric_value == nil then
        return "0"
    end

    if numeric_value % 1 == 0 then
        return tostring(math.floor(numeric_value))
    end

    return string.format("%.2f", numeric_value):gsub("0+$", ""):gsub("%.$", "")
end

local function build_reward_summary_text(reward_results)
    local parts = {}

    for _, reward_result in ipairs(reward_results or {}) do
        if trim_string(reward_result.item_key) ~= nil then
            parts[#parts + 1] = string.format(
                "%s x%s",
                tostring(reward_result.item_key),
                tostring(reward_result.quantity)
            )
        end
    end

    return table.concat(parts, ", ")
end

local function build_node_line(node_row)
    local requirement_parts = {}

    if trim_string(node_row.required_item_key) ~= nil then
        requirement_parts[#requirement_parts + 1] = string.format(
            "req_item=%sx%s",
            tostring(node_row.required_item_key),
            tostring(node_row.required_item_quantity or 1)
        )
    end

    if trim_string(node_row.required_skill_key) ~= nil and node_row.required_skill_level ~= nil then
        requirement_parts[#requirement_parts + 1] = string.format(
            "req_level=%s",
            tostring(node_row.required_skill_level)
        )
    end

    local line = string.format(
        "- %s item=%s qty=%s-%s stock=%s cooldown=%ss active=%s skill=%s xp=%s",
        tostring(node_row.key),
        tostring(node_row.result_item_key),
        tostring(node_row.min_quantity),
        tostring(node_row.max_quantity),
        tostring(build_stock_text(node_row)),
        tostring(node_row.cooldown_seconds),
        tostring(node_row.is_active),
        tostring(node_row.required_skill_key or "none"),
        tostring(node_row.skill_xp or 0)
    )

    if #requirement_parts > 0 then
        line = string.format("%s %s", line, table.concat(requirement_parts, " "))
    end

    return line
end

local function build_node_info_lines(node_info)
    local lines = {}
    local requirement_text = "aucun"
    local node_row = get_node_row(node_info)
    local reward_rows = type(node_info) == "table" and node_info.rewards or nil

    lines[#lines + 1] = string.format("Node %s :", tostring(node_row.key))
    lines[#lines + 1] = string.format(
        "item=%s qty=%s-%s stock=%s restock=%s cooldown=%ss skill=%s xp=%s proximity=%s",
        tostring(node_row.result_item_key),
        tostring(node_row.min_quantity),
        tostring(node_row.max_quantity),
        tostring(build_stock_text(node_row)),
        tostring(build_restock_text(node_row)),
        tostring(node_row.cooldown_seconds),
        tostring(node_row.required_skill_key or "none"),
        tostring(node_row.skill_xp or 0),
        tostring(node_row.requires_proximity)
    )

    if trim_string(node_row.required_item_key) ~= nil
        and trim_string(node_row.required_skill_key) ~= nil
        and node_row.required_skill_level ~= nil
    then
        requirement_text = string.format(
            "%s x%s, %s level %s",
            tostring(node_row.required_item_key),
            tostring(node_row.required_item_quantity or 1),
            tostring(node_row.required_skill_key),
            tostring(node_row.required_skill_level)
        )
    elseif trim_string(node_row.required_item_key) ~= nil then
        requirement_text = string.format(
            "%s x%s",
            tostring(node_row.required_item_key),
            tostring(node_row.required_item_quantity or 1)
        )
    elseif trim_string(node_row.required_skill_key) ~= nil and node_row.required_skill_level ~= nil then
        requirement_text = string.format(
            "%s level %s",
            tostring(node_row.required_skill_key),
            tostring(node_row.required_skill_level)
        )
    end

    lines[#lines + 1] = string.format("requires: %s", requirement_text)

    if type(reward_rows) == "table" and #reward_rows > 0 then
        lines[#lines + 1] = "Rewards:"

        for _, reward_row in ipairs(reward_rows) do
            lines[#lines + 1] = string.format(
                "- %s %s qty=%s-%s chance=%s%%",
                tostring(reward_row.reward_type),
                tostring(reward_row.item_key),
                tostring(reward_row.min_quantity),
                tostring(reward_row.max_quantity),
                tostring(format_chance_percent(reward_row.chance_percent))
            )
        end
    else
        lines[#lines + 1] = string.format(
            "Rewards: legacy %s qty=%s-%s",
            tostring(node_row.result_item_key),
            tostring(node_row.min_quantity),
            tostring(node_row.max_quantity)
        )
    end

    return lines
end

local database_service = resolve_database_service()

GRGathering.Server.Repository = GatheringRepository.Create(database_service)
GRGathering.Server.Service = GatheringService.Create(GRGathering.Server.Repository)

GRGatheringBridge = GRGatheringBridge or {}

GRGatheringBridge.GetService = function()
    return GRGathering.Server.Service
end

GRGatheringBridge.ListNodes = function(callback)
    if GRGathering.Server.Service == nil then
        return callback_service_missing(callback)
    end

    return GRGathering.Server.Service:ListNodes(callback)
end

GRGatheringBridge.GetNodeInfo = function(node_key, callback)
    if GRGathering.Server.Service == nil then
        return callback_service_missing(callback)
    end

    return GRGathering.Server.Service:GetNodeInfo(node_key, callback)
end

GRGatheringBridge.Gather = function(character_id, player, node_key, callback)
    if GRGathering.Server.Service == nil then
        return callback_service_missing(callback)
    end

    return GRGathering.Server.Service:Gather(character_id, player, node_key, callback)
end

GRGatheringBridge.RestockNode = function(node_key, quantity, callback)
    if GRGathering.Server.Service == nil then
        return callback_service_missing(callback)
    end

    return GRGathering.Server.Service:RestockNode(node_key, quantity, callback)
end

Package.Export("GRGatheringBridge", GRGatheringBridge)

if type(Chat) == "table" and type(Chat.Subscribe) == "function" and type(Chat.SendMessage) == "function" then
    Chat.Subscribe("PlayerSubmit", function(first_argument, second_argument)
        local player, message = normalize_chat_submit_arguments(first_argument, second_argument)
        local command_name = nil
        local payload = nil

        if player == nil then
            return
        end

        command_name, payload = get_chat_command(message)

        if command_name ~= "gathernodes"
            and command_name ~= "gatherinfo"
            and command_name ~= "gather"
            and command_name ~= "restocknode"
        then
            return
        end

        local is_allowed = false
        local platform_id = nil
        local guard_error = nil

        is_allowed, platform_id, guard_error = can_use_gathering_debug_commands(player)

        if not is_allowed then
            Console.Log(
                "[gr_gathering][server] Gathering debug command denied platform_id=%s reason=%s.",
                tostring(platform_id),
                tostring(guard_error)
            )
            Chat.SendMessage(player, "Commande recolte desactivee.")
            return false
        end

        if command_name == "gathernodes" then
            GRGathering.Server.Service:ListNodes(function(is_success, node_rows, error)
                if not is_success then
                    Chat.SendMessage(player, "Nodes de recolte indisponibles.")
                    return
                end

                Chat.SendMessage(player, "Nodes de recolte :")

                if type(node_rows) ~= "table" or #node_rows == 0 then
                    Chat.SendMessage(player, "- aucun")
                    return
                end

                for _, node_row in ipairs(node_rows) do
                    Chat.SendMessage(player, build_node_line(node_row))
                end
            end)

            return false
        end

        if command_name == "restocknode" then
            local node_key = nil
            local quantity_text = nil
            local quantity = nil

            if payload == nil then
                Chat.SendMessage(player, "Usage : /restocknode <node_key> [quantity]")
                return false
            end

            node_key, quantity_text = payload:match("^(%S+)%s*(.*)$")
            node_key = trim_string(node_key)
            quantity_text = trim_string(quantity_text)

            if node_key == nil then
                Chat.SendMessage(player, "Usage : /restocknode <node_key> [quantity]")
                return false
            end

            if quantity_text ~= nil then
                quantity = normalize_positive_integer(quantity_text)

                if quantity == nil or quantity > 1000 then
                    Chat.SendMessage(player, "Restock impossible : quantite invalide.")
                    return false
                end
            end

            GRGathering.Server.Service:RestockNode(node_key, quantity, function(is_success, result, error)
                if not is_success then
                    if error == "stock-disabled" then
                        Chat.SendMessage(player, "Restock impossible : stock desactive pour ce node.")
                        return
                    end

                    if error == "quantity-required" then
                        Chat.SendMessage(player, "Restock impossible : quantite invalide.")
                        return
                    end

                    Chat.SendMessage(player, "Restock impossible : erreur node.")
                    return
                end

                Chat.SendMessage(
                    player,
                    string.format(
                        "Stock node mis a jour : %s stock=%s/%s.",
                        tostring(node_key),
                        tostring(result.stock_quantity),
                        tostring(result.max_stock)
                    )
                )
            end)

            return false
        end

        if payload == nil then
            if command_name == "gatherinfo" then
                Chat.SendMessage(player, "Usage : /gatherinfo <node_key>")
                return false
            end

            Chat.SendMessage(player, "Usage : /gather <node_key>")
            return false
        end

        if command_name == "gatherinfo" then
            GRGathering.Server.Service:GetNodeInfo(payload, function(is_success, node_info, error)
                if not is_success then
                    if error == "node-not-found" or error == "node-key-required" then
                        Chat.SendMessage(player, "Node introuvable.")
                        return
                    end

                    Chat.SendMessage(player, "Node indisponible.")
                    return
                end

                for _, line in ipairs(build_node_info_lines(node_info)) do
                    Chat.SendMessage(player, line)
                end
            end)

            return false
        end

        local active_character_id = resolve_active_character_id(player)

        if active_character_id == nil then
            Chat.SendMessage(player, "Recolte impossible : personnage actif introuvable.")
            return false
        end

        GRGathering.Server.Service:Gather(active_character_id, player, payload, function(is_success, result, error)
            if not is_success then
                if error == "node-not-found" or error == "node-key-required" then
                    Chat.SendMessage(player, "Recolte impossible : node introuvable.")
                    return
                end

                if error == "node-inactive" then
                    Chat.SendMessage(player, "Recolte impossible : node inactif.")
                    return
                end

                if error == "node-exhausted" then
                    Chat.SendMessage(player, "Recolte impossible : node epuise.")
                    return
                end

                if error == "too-far" then
                    Chat.SendMessage(player, "Recolte impossible : vous etes trop loin.")
                    return
                end

                if error == "cooldown-active" then
                    Chat.SendMessage(
                        player,
                        string.format(
                            "Recolte impossible : cooldown restant %ss.",
                            tostring(type(result) == "table" and result.remaining_seconds or 0)
                        )
                    )
                    return
                end

                if error == "required-item-missing" then
                    Chat.SendMessage(
                        player,
                        string.format(
                            "Recolte impossible : outil requis manquant %s x%s.",
                            tostring(type(result) == "table" and result.required_item_key or "unknown"),
                            tostring(type(result) == "table" and result.required_item_quantity or 1)
                        )
                    )
                    return
                end

                if error == "skill-level-insufficient" then
                    Chat.SendMessage(
                        player,
                        string.format(
                            "Recolte impossible : niveau %s insuffisant %s/%s.",
                            tostring(type(result) == "table" and result.required_skill_key or "unknown"),
                            tostring(type(result) == "table" and result.current_skill_level or 0),
                            tostring(type(result) == "table" and result.required_skill_level or 0)
                        )
                    )
                    return
                end

                if error == "inventory-check-unavailable" then
                    Chat.SendMessage(player, "Recolte impossible : verification outil impossible.")
                    return
                end

                if error == "skill-check-unavailable" then
                    Chat.SendMessage(player, "Recolte impossible : verification skill impossible.")
                    return
                end

                if error == "inventory-unavailable" then
                    Chat.SendMessage(player, "Recolte impossible : inventaire indisponible.")
                    return
                end

                if error == "stock-insufficient" or error == "stock-update-failed" then
                    Chat.SendMessage(player, "Recolte impossible : stock insuffisant.")
                    return
                end

                if error == "stock-compensation-failed" then
                    Chat.SendMessage(player, "Recolte impossible : erreur stock.")
                    return
                end

                if error == "no-reward-generated" then
                    Chat.SendMessage(player, "Recolte impossible : aucune recompense generee.")
                    return
                end

                if error == "player-position-unavailable" or error == "node-position-invalid" then
                    Chat.SendMessage(player, "Recolte impossible : position indisponible.")
                    return
                end

                if error == "invalid-character" then
                    Chat.SendMessage(player, "Recolte impossible : personnage actif introuvable.")
                    return
                end

                Chat.SendMessage(player, "Recolte impossible : erreur serveur.")
                return
            end

            if type(result) == "table" and type(result.skill) == "table" then
                Chat.SendMessage(
                    player,
                    string.format(
                        "Recolte effectuee : %s, xp=%s+%s.",
                        tostring(build_reward_summary_text(result.rewards)),
                        tostring(result.skill.skill_key),
                        tostring(result.skill.amount or 0)
                    )
                )
                return
            end

            Chat.SendMessage(
                player,
                string.format(
                    "Recolte effectuee : %s.",
                    tostring(type(result) == "table" and build_reward_summary_text(result.rewards) or payload)
                )
            )
        end)

        return false
    end)
end

Console.Log("[gr_gathering][server] Gathering package loaded.")
Console.Log("[gr_gathering][server] Gathering bridge exported.")

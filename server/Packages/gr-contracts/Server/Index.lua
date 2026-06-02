Package.Require("../Shared/Index.lua")

local ContractRepository = Package.Require("ContractRepository.lua")
local ContractService = Package.Require("ContractService.lua")

GRContracts = GRContracts or {}
GRContracts.Server = GRContracts.Server or {}

local function resolve_database_service()
    if type(GRDatabaseBridge) == "table" and type(GRDatabaseBridge.GetService) == "function" then
        return GRDatabaseBridge.GetService()
    end

    return nil
end

local function callback_service_missing(callback)
    if type(callback) == "function" then
        callback(false, nil, "contracts-service-missing")
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

local function can_use_contracts_debug_commands(player_or_platform_id)
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

    debug_commands_enabled = normalize_boolean(custom_settings.gr_contracts_debug_commands_enabled, false)

    if not debug_commands_enabled then
        return false, platform_id, "debug-disabled"
    end

    allowlist, has_allowlist_entries = parse_platform_id_allowlist(custom_settings.gr_contracts_debug_allowed_platform_ids)

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

local function build_contract_line(contract_row)
    return string.format(
        "- #%s %s reward=%s status=%s desc=%s",
        tostring(contract_row.id),
        tostring(contract_row.type),
        tostring(contract_row.reward_money),
        tostring(contract_row.status),
        tostring(contract_row.description)
    )
end

local function build_my_contract_line(contract_row)
    return string.format(
        "- #%s %s reward=%s status=%s role=%s",
        tostring(contract_row.id),
        tostring(contract_row.type),
        tostring(contract_row.reward_money),
        tostring(contract_row.status),
        tostring(contract_row.role or "unknown")
    )
end

local database_service = resolve_database_service()

GRContracts.Server.Repository = ContractRepository.Create(database_service)
GRContracts.Server.Service = ContractService.Create(GRContracts.Server.Repository)

if database_service ~= nil then
    Console.Log("[gr_contracts][server] Database service resolved through GRDatabaseBridge.")
else
    Console.Log("[gr_contracts][server] Database service unavailable because GRDatabaseBridge is missing.")
end

GRContractsBridge = GRContractsBridge or {}

GRContractsBridge.GetService = function()
    return GRContracts.Server.Service
end

GRContractsBridge.CreateContract = function(character_id, contract_type, reward_money, description, callback)
    if GRContracts.Server.Service == nil then
        return callback_service_missing(callback)
    end

    return GRContracts.Server.Service:CreateContract(character_id, contract_type, reward_money, description, callback)
end

GRContractsBridge.ListOpenContracts = function(callback)
    if GRContracts.Server.Service == nil then
        return callback_service_missing(callback)
    end

    return GRContracts.Server.Service:ListOpenContracts(callback)
end

GRContractsBridge.ListMyContracts = function(character_id, callback)
    if GRContracts.Server.Service == nil then
        return callback_service_missing(callback)
    end

    return GRContracts.Server.Service:ListMyContracts(character_id, callback)
end

GRContractsBridge.AcceptContract = function(character_id, contract_id, callback)
    if GRContracts.Server.Service == nil then
        return callback_service_missing(callback)
    end

    return GRContracts.Server.Service:AcceptContract(character_id, contract_id, callback)
end

GRContractsBridge.CompleteContract = function(character_id, contract_id, callback)
    if GRContracts.Server.Service == nil then
        return callback_service_missing(callback)
    end

    return GRContracts.Server.Service:CompleteContract(character_id, contract_id, callback)
end

GRContractsBridge.CancelContract = function(character_id, contract_id, callback)
    if GRContracts.Server.Service == nil then
        return callback_service_missing(callback)
    end

    return GRContracts.Server.Service:CancelContract(character_id, contract_id, callback)
end

Package.Export("GRContractsBridge", GRContractsBridge)

if type(Chat) == "table" and type(Chat.Subscribe) == "function" and type(Chat.SendMessage) == "function" then
    Chat.Subscribe("PlayerSubmit", function(first_argument, second_argument)
        local player, message = normalize_chat_submit_arguments(first_argument, second_argument)
        local command_name = nil
        local payload = nil

        if player == nil then
            return
        end

        command_name, payload = get_chat_command(message)

        if command_name ~= "contracts"
            and command_name ~= "mycontracts"
            and command_name ~= "createcontract"
            and command_name ~= "acceptcontract"
            and command_name ~= "completecontract"
            and command_name ~= "cancelcontract"
        then
            return
        end

        local is_allowed = false
        local platform_id = nil
        local guard_error = nil

        is_allowed, platform_id, guard_error = can_use_contracts_debug_commands(player)

        if not is_allowed then
            Console.Log(
                "[gr_contracts][server] Contracts debug command denied platform_id=%s reason=%s.",
                tostring(platform_id),
                tostring(guard_error)
            )
            Chat.SendMessage(player, "Commande contrats desactivee.")
            return false
        end

        local active_character_id = resolve_active_character_id(player)

        if active_character_id == nil then
            Chat.SendMessage(player, "Personnage actif introuvable.")
            return false
        end

        if command_name == "contracts" then
            GRContracts.Server.Service:ListOpenContracts(function(is_success, contract_rows, error)
                if not is_success then
                    Chat.SendMessage(player, "Contrats indisponibles.")
                    return
                end

                if type(contract_rows) ~= "table" or #contract_rows == 0 then
                    Chat.SendMessage(player, "Aucun contrat ouvert.")
                    return
                end

                Chat.SendMessage(player, "Contrats ouverts :")

                for _, contract_row in ipairs(contract_rows) do
                    Chat.SendMessage(player, build_contract_line(contract_row))
                end
            end)

            return false
        end

        if command_name == "mycontracts" then
            GRContracts.Server.Service:ListMyContracts(active_character_id, function(is_success, contract_rows, error)
                if not is_success then
                    Chat.SendMessage(player, "Mes contrats sont indisponibles.")
                    return
                end

                if type(contract_rows) ~= "table" or #contract_rows == 0 then
                    Chat.SendMessage(player, "Aucun contrat.")
                    return
                end

                Chat.SendMessage(player, "Mes contrats :")

                for _, contract_row in ipairs(contract_rows) do
                    Chat.SendMessage(player, build_my_contract_line(contract_row))
                end
            end)

            return false
        end

        if command_name == "createcontract" then
            if payload == nil then
                Chat.SendMessage(player, "Usage : /createcontract <type> <reward_money> <description>")
                return false
            end

            local contract_type, reward_money_text, description = payload:match("^(%S+)%s+([+-]?%d+)%s+(.+)$")

            if contract_type == nil then
                Chat.SendMessage(player, "Usage : /createcontract <type> <reward_money> <description>")
                return false
            end

            GRContracts.Server.Service:CreateContract(active_character_id, contract_type, reward_money_text, description, function(is_success, contract_row, error)
                if not is_success then
                    if error == "contract-type-invalid" then
                        Chat.SendMessage(player, "Type de contrat invalide.")
                        return
                    end

                    if error == "reward-money-invalid" then
                        Chat.SendMessage(player, "Montant invalide.")
                        return
                    end

                    if error == "description-invalid" then
                        Chat.SendMessage(player, "Description invalide.")
                        return
                    end

                    Chat.SendMessage(player, "Impossible de creer le contrat.")
                    return
                end

                Chat.SendMessage(
                    player,
                    string.format(
                        "Contrat cree : #%s %s reward=%s",
                        tostring(contract_row.id),
                        tostring(contract_row.type),
                        tostring(contract_row.reward_money)
                    )
                )
            end)

            return false
        end

        if payload == nil then
            if command_name == "acceptcontract" then
                Chat.SendMessage(player, "Usage : /acceptcontract <contract_id>")
            elseif command_name == "completecontract" then
                Chat.SendMessage(player, "Usage : /completecontract <contract_id>")
            else
                Chat.SendMessage(player, "Usage : /cancelcontract <contract_id>")
            end

            return false
        end

        local contract_id = normalize_positive_integer(payload)

        if contract_id == nil then
            Chat.SendMessage(player, "Contrat introuvable.")
            return false
        end

        if command_name == "acceptcontract" then
            GRContracts.Server.Service:AcceptContract(active_character_id, contract_id, function(is_success, contract_row, error)
                if not is_success then
                    if error == "contract-not-found" then
                        Chat.SendMessage(player, "Contrat introuvable.")
                        return
                    end

                    if error == "contract-not-available" then
                        Chat.SendMessage(player, "Contrat non disponible.")
                        return
                    end

                    Chat.SendMessage(player, "Impossible d'accepter ce contrat.")
                    return
                end

                Chat.SendMessage(player, string.format("Contrat accepte : #%s", tostring(contract_row.id)))
            end)

            return false
        end

        if command_name == "completecontract" then
            GRContracts.Server.Service:CompleteContract(active_character_id, contract_id, function(is_success, contract_row, error)
                if not is_success then
                    if error == "contract-not-found" then
                        Chat.SendMessage(player, "Contrat introuvable.")
                        return
                    end

                    if error == "contract-complete-forbidden" then
                        Chat.SendMessage(player, "Vous ne pouvez pas terminer ce contrat.")
                        return
                    end

                    Chat.SendMessage(player, "Impossible de terminer ce contrat.")
                    return
                end

                Chat.SendMessage(player, string.format("Contrat termine : #%s", tostring(contract_row.id)))
            end)

            return false
        end

        GRContracts.Server.Service:CancelContract(active_character_id, contract_id, function(is_success, contract_row, error)
            if not is_success then
                if error == "contract-not-found" then
                    Chat.SendMessage(player, "Contrat introuvable.")
                    return
                end

                if error == "contract-cancel-forbidden" then
                    Chat.SendMessage(player, "Vous ne pouvez pas annuler ce contrat.")
                    return
                end

                Chat.SendMessage(player, "Impossible d'annuler ce contrat.")
                return
            end

            Chat.SendMessage(player, string.format("Contrat annule : #%s", tostring(contract_row.id)))
        end)

        return false
    end)
end

Console.Log("[gr_contracts][server] Contracts package loaded.")
Console.Log("[gr_contracts][server] Contracts bridge exported.")

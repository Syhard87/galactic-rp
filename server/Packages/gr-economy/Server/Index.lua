Package.Require("../Shared/Index.lua")

local EconomyRepository = Package.Require("EconomyRepository.lua")
local EconomyService = Package.Require("EconomyService.lua")

GREconomy = GREconomy or {}
GREconomy.Server = GREconomy.Server or {}

local function resolve_database_service()
    if type(GRDatabaseBridge) == "table" and type(GRDatabaseBridge.GetService) == "function" then
        return GRDatabaseBridge.GetService()
    end

    return nil
end

local function callback_service_missing(callback)
    if type(callback) == "function" then
        callback(false, nil, "economy-service-missing")
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

local function normalize_wallet(wallet)
    local normalized_wallet = trim_string(wallet)

    if normalized_wallet == nil then
        return nil
    end

    normalized_wallet = string.lower(normalized_wallet)

    if normalized_wallet ~= "cash" and normalized_wallet ~= "bank" then
        return nil
    end

    return normalized_wallet
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

local function can_use_economy_debug_commands(player_or_platform_id)
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

    debug_commands_enabled = normalize_boolean(custom_settings.gr_economy_debug_commands_enabled, false)

    if not debug_commands_enabled then
        return false, platform_id, "debug-disabled"
    end

    allowlist, has_allowlist_entries = parse_platform_id_allowlist(custom_settings.gr_economy_debug_allowed_platform_ids)

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

local function build_transaction_line(transaction_row)
    local direction_prefix = "+"

    if transaction_row.type == "debit" or transaction_row.type == "transfer_out" then
        direction_prefix = "-"
    end

    return string.format(
        "- %s %s %s%s reason=%s",
        tostring(transaction_row.type),
        tostring(transaction_row.wallet),
        tostring(direction_prefix),
        tostring(transaction_row.amount),
        tostring(transaction_row.reason)
    )
end

local function truncate_text(value, max_length)
    local normalized_value = trim_string(value)

    if normalized_value == nil then
        return ""
    end

    if type(max_length) ~= "number" or max_length < 4 or #normalized_value <= max_length then
        return normalized_value
    end

    return normalized_value:sub(1, max_length - 3) .. "..."
end

local function build_diagnostic_transaction_line(transaction_row)
    local direction_prefix = "+"
    local truncated_reason = truncate_text(transaction_row and transaction_row.reason, 48)

    if transaction_row.type == "debit" or transaction_row.type == "transfer_out" then
        direction_prefix = "-"
    end

    return string.format(
        "#%s %s %s %s%s reason=%s",
        tostring(transaction_row.id),
        tostring(transaction_row.type),
        tostring(transaction_row.wallet),
        tostring(direction_prefix),
        tostring(transaction_row.amount),
        tostring(truncated_reason)
    )
end

local database_service = resolve_database_service()

GREconomy.Server.Repository = EconomyRepository.Create(database_service)
GREconomy.Server.Service = EconomyService.Create(GREconomy.Server.Repository)

if database_service ~= nil then
    Console.Log("[gr_economy][server] Database service resolved through GRDatabaseBridge.")
else
    Console.Log("[gr_economy][server] Database service unavailable because GRDatabaseBridge is missing.")
end

GREconomyBridge = GREconomyBridge or {}

GREconomyBridge.GetService = function()
    return GREconomy.Server.Service
end

GREconomyBridge.GetBalance = function(character_id, callback)
    if GREconomy.Server.Service == nil then
        return callback_service_missing(callback)
    end

    return GREconomy.Server.Service:GetBalance(character_id, callback)
end

GREconomyBridge.AddMoney = function(character_id, wallet, amount, reason, metadata, callback)
    if GREconomy.Server.Service == nil then
        return callback_service_missing(callback)
    end

    return GREconomy.Server.Service:AddMoney(character_id, wallet, amount, reason, metadata, callback)
end

GREconomyBridge.RemoveMoney = function(character_id, wallet, amount, reason, metadata, callback)
    if GREconomy.Server.Service == nil then
        return callback_service_missing(callback)
    end

    return GREconomy.Server.Service:RemoveMoney(character_id, wallet, amount, reason, metadata, callback)
end

GREconomyBridge.TransferMoney = function(from_character_id, to_character_id, wallet, amount, reason, callback)
    if GREconomy.Server.Service == nil then
        return callback_service_missing(callback)
    end

    return GREconomy.Server.Service:TransferMoney(from_character_id, to_character_id, wallet, amount, reason, callback)
end

GREconomyBridge.ListTransactions = function(character_id, limit, callback)
    if GREconomy.Server.Service == nil then
        return callback_service_missing(callback)
    end

    return GREconomy.Server.Service:ListTransactions(character_id, limit, callback)
end

GREconomyBridge.ClaimSalary = function(character_id, callback)
    if GREconomy.Server.Service == nil then
        return callback_service_missing(callback)
    end

    return GREconomy.Server.Service:ClaimSalary(character_id, callback)
end

GREconomyBridge.ListSalaryRules = function(callback)
    if GREconomy.Server.Service == nil then
        return callback_service_missing(callback)
    end

    return GREconomy.Server.Service:ListSalaryRules(callback)
end

GREconomyBridge.GetBalanceDiagnostic = function(character_id, callback)
    if GREconomy.Server.Service == nil then
        return callback_service_missing(callback)
    end

    return GREconomy.Server.Service:GetBalanceDiagnostic(character_id, callback)
end

GREconomyBridge.ListTransactionsDiagnostic = function(character_id, limit, callback)
    if GREconomy.Server.Service == nil then
        return callback_service_missing(callback)
    end

    return GREconomy.Server.Service:ListTransactionsDiagnostic(character_id, limit, callback)
end

GREconomyBridge.GetSalaryDiagnostic = function(character_id, callback)
    if GREconomy.Server.Service == nil then
        return callback_service_missing(callback)
    end

    return GREconomy.Server.Service:GetSalaryDiagnostic(character_id, callback)
end

GREconomyBridge.GetEconomyHealth = function(callback)
    if GREconomy.Server.Service == nil then
        return callback_service_missing(callback)
    end

    return GREconomy.Server.Service:GetEconomyHealth(callback)
end

Package.Export("GREconomyBridge", GREconomyBridge)

if type(Chat) == "table" and type(Chat.Subscribe) == "function" and type(Chat.SendMessage) == "function" then
    Chat.Subscribe("PlayerSubmit", function(first_argument, second_argument)
        local player, message = normalize_chat_submit_arguments(first_argument, second_argument)
        local command_name = nil
        local payload = nil

        if player == nil then
            return
        end

        command_name, payload = get_chat_command(message)

        if command_name ~= "money"
            and command_name ~= "givemoney"
            and command_name ~= "takemoney"
            and command_name ~= "transactions"
            and command_name ~= "pay"
            and command_name ~= "claimsalary"
            and command_name ~= "salaryrules"
            and command_name ~= "economybalance"
            and command_name ~= "economytransactions"
            and command_name ~= "economysalary"
            and command_name ~= "economyhealth"
        then
            return
        end

        local is_allowed = false
        local platform_id = nil
        local guard_error = nil

        is_allowed, platform_id, guard_error = can_use_economy_debug_commands(player)

        if not is_allowed then
            Console.Log(
                "[gr_economy][server] Economy debug command denied platform_id=%s reason=%s.",
                tostring(platform_id),
                tostring(guard_error)
            )
            if command_name == "economybalance"
                or command_name == "economytransactions"
                or command_name == "economysalary"
                or command_name == "economyhealth"
            then
                Chat.SendMessage(player, "Diagnostic economie desactive.")
                return false
            end

            Chat.SendMessage(player, "Commande economie desactivee.")
            return false
        end

        if command_name == "salaryrules" then
            GREconomy.Server.Service:ListSalaryRules(function(is_success, salary_rules, error)
                if not is_success then
                    Chat.SendMessage(player, "Salaire indisponible.")
                    return
                end

                if type(salary_rules) ~= "table" or #salary_rules == 0 then
                    Chat.SendMessage(player, "Regles de salaire :")
                    Chat.SendMessage(player, "- aucune")
                    return
                end

                Chat.SendMessage(player, "Regles de salaire :")

                for _, salary_rule in ipairs(salary_rules) do
                    Chat.SendMessage(
                        player,
                        string.format(
                            "- %s amount=%s wallet=%s cooldown=%ss active=%s",
                            tostring(salary_rule.key),
                            tostring(salary_rule.amount),
                            tostring(salary_rule.wallet),
                            tostring(salary_rule.cooldown_seconds),
                            tostring(salary_rule.is_active)
                        )
                    )
                end
            end)

            return false
        end

        if command_name == "economyhealth" then
            GREconomy.Server.Service:GetEconomyHealth(function(is_success, economy_health, error)
                if not is_success or economy_health == nil then
                    Chat.SendMessage(player, "Diagnostic economie indisponible.")
                    return
                end

                Chat.SendMessage(
                    player,
                    string.format(
                        "Economy health : characters=%s transactions=%s salary_rules=%s",
                        tostring(economy_health.character_count),
                        tostring(economy_health.transaction_count),
                        tostring(economy_health.salary_rule_count)
                    )
                )
            end)

            return false
        end

        local active_character_id = resolve_active_character_id(player)

        if active_character_id == nil then
            if command_name == "economybalance"
                or command_name == "economytransactions"
                or command_name == "economysalary"
                or command_name == "money"
                or command_name == "transactions"
                or command_name == "claimsalary"
                or command_name == "pay"
                or command_name == "givemoney"
                or command_name == "takemoney"
            then
                Chat.SendMessage(player, "Personnage actif introuvable.")
                return false
            end
        end

        if command_name == "economybalance" then
            local target_character_id = normalize_positive_integer(payload)

            if target_character_id == nil then
                Chat.SendMessage(player, "Character id invalide.")
                return false
            end

            GREconomy.Server.Service:GetBalanceDiagnostic(target_character_id, function(is_success, balance_row, error)
                if not is_success then
                    if error == "character-id-required" then
                        Chat.SendMessage(player, "Character id invalide.")
                        return
                    end

                    Chat.SendMessage(player, "Diagnostic economie indisponible.")
                    return
                end

                if balance_row == nil then
                    Chat.SendMessage(player, "Personnage introuvable.")
                    return
                end

                Chat.SendMessage(
                    player,
                    string.format(
                        "Balance #%s : cash=%s bank=%s",
                        tostring(target_character_id),
                        tostring(balance_row.cash),
                        tostring(balance_row.bank)
                    )
                )
            end)

            return false
        end

        if command_name == "economytransactions" then
            local target_character_id_text = nil
            local limit_text = nil
            local target_character_id = nil
            local limit = nil

            if payload ~= nil then
                target_character_id_text, limit_text = payload:match("^(%S+)%s*(%S*)$")
            end

            target_character_id = normalize_positive_integer(target_character_id_text)
            limit = normalize_positive_integer(limit_text) or 10

            if target_character_id == nil then
                Chat.SendMessage(player, "Character id invalide.")
                return false
            end

            GREconomy.Server.Service:ListTransactionsDiagnostic(target_character_id, limit, function(is_success, transaction_rows, error)
                if not is_success then
                    if error == "character-id-required" then
                        Chat.SendMessage(player, "Character id invalide.")
                        return
                    end

                    Chat.SendMessage(player, "Diagnostic economie indisponible.")
                    return
                end

                Chat.SendMessage(player, string.format("Transactions #%s :", tostring(target_character_id)))

                if type(transaction_rows) ~= "table" or #transaction_rows == 0 then
                    Chat.SendMessage(player, "- aucune")
                    return
                end

                for _, transaction_row in ipairs(transaction_rows) do
                    Chat.SendMessage(player, build_diagnostic_transaction_line(transaction_row))
                end
            end)

            return false
        end

        if command_name == "economysalary" then
            local target_character_id = normalize_positive_integer(payload)

            if target_character_id == nil then
                Chat.SendMessage(player, "Character id invalide.")
                return false
            end

            GREconomy.Server.Service:GetSalaryDiagnostic(target_character_id, function(is_success, salary_status, error)
                if not is_success then
                    if error == "character-id-required" then
                        Chat.SendMessage(player, "Character id invalide.")
                        return
                    end

                    if error == "character-not-found" then
                        Chat.SendMessage(player, "Personnage introuvable.")
                        return
                    end

                    Chat.SendMessage(player, "Diagnostic economie indisponible.")
                    return
                end

                if salary_status == nil or salary_status.salary_rule == nil then
                    Chat.SendMessage(player, string.format("Salaire #%s : aucune regle active.", tostring(target_character_id)))
                    return
                end

                Chat.SendMessage(
                    player,
                    string.format(
                        "Salaire #%s : rule=%s amount=%s wallet=%s cooldown_remaining=%ss",
                        tostring(target_character_id),
                        tostring(salary_status.salary_rule.key),
                        tostring(salary_status.salary_rule.amount),
                        tostring(salary_status.salary_rule.wallet),
                        tostring(salary_status.cooldown_remaining or 0)
                    )
                )
            end)

            return false
        end

        if command_name == "money" then
            GREconomy.Server.Service:GetBalance(active_character_id, function(is_success, balance_row, error)
                if not is_success or balance_row == nil then
                    Chat.SendMessage(player, "Argent indisponible.")
                    return
                end

                Chat.SendMessage(
                    player,
                    string.format(
                        "Argent : cash=%s bank=%s",
                        tostring(balance_row.cash),
                        tostring(balance_row.bank)
                    )
                )
            end)

            return false
        end

        if command_name == "transactions" then
            GREconomy.Server.Service:ListTransactions(active_character_id, 10, function(is_success, transaction_rows, error)
                if not is_success then
                    Chat.SendMessage(player, "Transactions indisponibles.")
                    return
                end

                if type(transaction_rows) ~= "table" or #transaction_rows == 0 then
                    Chat.SendMessage(player, "Transactions recentes :")
                    Chat.SendMessage(player, "- aucune")
                    return
                end

                Chat.SendMessage(player, "Transactions recentes :")

                for _, transaction_row in ipairs(transaction_rows) do
                    Chat.SendMessage(player, build_transaction_line(transaction_row))
                end
            end)

            return false
        end

        if command_name == "claimsalary" then
            GREconomy.Server.Service:ClaimSalary(active_character_id, function(is_success, result, error)
                if not is_success then
                    if error == "character-not-found" then
                        Chat.SendMessage(player, "Personnage actif introuvable.")
                        return
                    end

                    if error == "salary-rule-not-found" then
                        Chat.SendMessage(player, "Aucune regle de salaire pour votre faction.")
                        return
                    end

                    if error == "salary-on-cooldown" then
                        Chat.SendMessage(
                            player,
                            string.format(
                                "Salaire indisponible : cooldown restant %ss.",
                                tostring(result and result.remaining_seconds or 0)
                            )
                        )
                        return
                    end

                    if error == "payment-failed" then
                        Chat.SendMessage(player, "Erreur lors du versement du salaire.")
                        return
                    end

                    if error == "claim-update-failed" or error == "rollback-failed" then
                        Chat.SendMessage(player, "Erreur lors du versement du salaire.")
                        return
                    end

                    if error == "database-error" then
                        Chat.SendMessage(player, "Economie indisponible.")
                        return
                    end

                    Chat.SendMessage(player, "Salaire indisponible.")
                    return
                end

                local salary_rule = result and result.salary_rule or nil

                Chat.SendMessage(
                    player,
                    string.format(
                        "Salaire verse : %s %s.",
                        tostring(salary_rule and salary_rule.amount or 0),
                        tostring(salary_rule and salary_rule.wallet or "bank")
                    )
                )
            end)

            return false
        end

        if command_name == "pay" then
            if payload == nil then
                Chat.SendMessage(player, "Usage : /pay <target_character_id> <wallet> <amount> [reason]")
                return false
            end

            local target_character_id_text, wallet, amount_text, reason = payload:match("^(%S+)%s+(%S+)%s+([+-]?%d+)%s*(.*)$")
            local normalized_target_character_id = normalize_positive_integer(target_character_id_text)
            local normalized_wallet = normalize_wallet(wallet)
            local normalized_amount = normalize_positive_integer(amount_text)
            local normalized_reason = trim_string(reason) or "player-payment"

            if normalized_target_character_id == nil then
                Chat.SendMessage(player, "Paiement impossible : cible invalide.")
                return false
            end

            if normalized_target_character_id == active_character_id then
                Chat.SendMessage(player, "Paiement impossible : vous ne pouvez pas vous payer vous-meme.")
                return false
            end

            if normalized_wallet == nil then
                Chat.SendMessage(player, "Paiement impossible : wallet invalide.")
                return false
            end

            if normalized_amount == nil or normalized_amount > 100000 then
                Chat.SendMessage(player, "Paiement impossible : montant invalide.")
                return false
            end

            if type(GREconomyBridge) ~= "table" or type(GREconomyBridge.TransferMoney) ~= "function" then
                Chat.SendMessage(player, "Paiement impossible : economie indisponible.")
                return false
            end

            GREconomyBridge.TransferMoney(
                active_character_id,
                normalized_target_character_id,
                normalized_wallet,
                normalized_amount,
                normalized_reason,
                function(is_success, result, error)
                    if not is_success then
                        if error == "invalid-source-character" or error == "invalid-target-character" or error == "character-id-required" then
                            Chat.SendMessage(player, "Paiement impossible : cible invalide.")
                            return
                        end

                        if error == "same-character" or error == "transfer-same-character" then
                            Chat.SendMessage(player, "Paiement impossible : vous ne pouvez pas vous payer vous-meme.")
                            return
                        end

                        if error == "invalid-wallet" or error == "wallet-invalid" then
                            Chat.SendMessage(player, "Paiement impossible : wallet invalide.")
                            return
                        end

                        if error == "invalid-amount" or error == "amount-invalid" then
                            Chat.SendMessage(player, "Paiement impossible : montant invalide.")
                            return
                        end

                        if error == "insufficient-funds" then
                            Chat.SendMessage(player, "Paiement impossible : solde insuffisant.")
                            return
                        end

                        if error == "transfer-incomplete"
                            or error == "transaction-log-failed"
                            or error == "rollback-failed"
                        then
                            Chat.SendMessage(player, "Paiement impossible : transfert incomplet.")
                            return
                        end

                        Chat.SendMessage(player, "Paiement impossible : erreur economie.")
                        return
                    end

                    Chat.SendMessage(
                        player,
                        string.format(
                            "Paiement effectue : %s %s vers personnage #%s.",
                            tostring(normalized_amount),
                            tostring(normalized_wallet),
                            tostring(normalized_target_character_id)
                        )
                    )
                end
            )

            return false
        end

        if payload == nil then
            if command_name == "givemoney" then
                Chat.SendMessage(player, "Usage : /givemoney <wallet> <amount> [reason]")
            else
                Chat.SendMessage(player, "Usage : /takemoney <wallet> <amount> [reason]")
            end

            return false
        end

        local wallet, amount_text, reason = payload:match("^(%S+)%s+([+-]?%d+)%s*(.*)$")
        local normalized_wallet = normalize_wallet(wallet)
        local normalized_amount = normalize_positive_integer(amount_text)
        local normalized_reason = trim_string(reason) or "debug-command"

        if normalized_wallet == nil then
            Chat.SendMessage(player, "Wallet invalide.")
            return false
        end

        if normalized_amount == nil then
            Chat.SendMessage(player, "Montant invalide.")
            return false
        end

        if command_name == "givemoney" then
            GREconomy.Server.Service:AddMoney(active_character_id, normalized_wallet, normalized_amount, normalized_reason, nil, function(is_success, result, error)
                if not is_success then
                    if error == "wallet-invalid" then
                        Chat.SendMessage(player, "Wallet invalide.")
                        return
                    end

                    if error == "amount-invalid" then
                        Chat.SendMessage(player, "Montant invalide.")
                        return
                    end

                    Chat.SendMessage(player, "Impossible d'ajouter l'argent.")
                    return
                end

                Chat.SendMessage(
                    player,
                    string.format(
                        "Argent ajoute : %s +%s",
                        tostring(normalized_wallet),
                        tostring(normalized_amount)
                    )
                )
            end)

            return false
        end

        GREconomy.Server.Service:RemoveMoney(active_character_id, normalized_wallet, normalized_amount, normalized_reason, nil, function(is_success, result, error)
            if not is_success then
                if error == "wallet-invalid" then
                    Chat.SendMessage(player, "Wallet invalide.")
                    return
                end

                if error == "amount-invalid" then
                    Chat.SendMessage(player, "Montant invalide.")
                    return
                end

                if error == "insufficient-funds" then
                    Chat.SendMessage(player, "Solde insuffisant.")
                    return
                end

                Chat.SendMessage(player, "Impossible de retirer l'argent.")
                return
            end

            Chat.SendMessage(
                player,
                string.format(
                    "Argent retire : %s -%s",
                    tostring(normalized_wallet),
                    tostring(normalized_amount)
                )
            )
        end)

        return false
    end)
end

Console.Log("[gr_economy][server] Economy package loaded.")
Console.Log("[gr_economy][server] Economy bridge exported.")

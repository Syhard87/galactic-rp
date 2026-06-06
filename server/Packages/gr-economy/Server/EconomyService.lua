GREconomy = GREconomy or {}
GREconomy.Server = GREconomy.Server or {}

local EconomyService = {}
EconomyService.__index = EconomyService

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

local function normalize_amount(value)
    if type(value) == "number" then
        if value <= 0 or value > 1000000 or value % 1 ~= 0 then
            return nil
        end

        return math.floor(value)
    end

    if type(value) == "string" and value:match("^%d+$") ~= nil then
        local parsed_value = tonumber(value)

        if parsed_value ~= nil and parsed_value > 0 and parsed_value <= 1000000 then
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

local function normalize_reason(reason)
    return trim_string(reason) or "unspecified"
end

local function normalize_limit(limit)
    local normalized_limit = normalize_positive_integer(limit) or 10

    if normalized_limit > 50 then
        return 50
    end

    return normalized_limit
end

local function callback_repository_missing(callback)
    if type(callback) == "function" then
        callback(false, nil, "economy-repository-missing")
    end

    return true
end

function EconomyService.Create(repository)
    local self = setmetatable({}, EconomyService)

    self.repository = repository

    return self
end

function EconomyService:GetBalance(character_id, callback)
    local normalized_character_id = normalize_positive_integer(character_id)

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if self.repository == nil then
        return callback_repository_missing(callback)
    end

    if normalized_character_id == nil then
        callback(false, nil, "character-id-required")
        return true
    end

    return self.repository:GetCharacterMoney(normalized_character_id, function(is_success, money_row, error)
        if not is_success then
            callback(false, nil, error)
            return
        end

        if money_row == nil then
            callback(false, nil, "character-not-found")
            return
        end

        callback(true, money_row, nil)
    end)
end

function EconomyService:AddMoney(character_id, wallet, amount, reason, metadata, callback)
    local normalized_character_id = normalize_positive_integer(character_id)
    local normalized_wallet = normalize_wallet(wallet)
    local normalized_amount = normalize_amount(amount)
    local normalized_reason = normalize_reason(reason)

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if self.repository == nil then
        return callback_repository_missing(callback)
    end

    if normalized_character_id == nil then
        callback(false, nil, "character-id-required")
        return true
    end

    if normalized_wallet == nil then
        callback(false, nil, "wallet-invalid")
        return true
    end

    if normalized_amount == nil then
        callback(false, nil, "amount-invalid")
        return true
    end

    return self.repository:UpdateWallet(normalized_character_id, normalized_wallet, normalized_amount, function(is_update_success, money_row, update_error)
        if not is_update_success or money_row == nil then
            Console.Log(
                "[gr_economy][service] Money operation failed reason=%s character_id=%s wallet=%s amount=%s.",
                tostring(update_error or "wallet-update-failed"),
                tostring(normalized_character_id),
                tostring(normalized_wallet),
                tostring(normalized_amount)
            )
            callback(false, nil, update_error or "wallet-update-failed")
            return
        end

        self.repository:InsertTransaction({
            character_id = normalized_character_id,
            amount = normalized_amount,
            currency = "credits",
            wallet = normalized_wallet,
            type = "credit",
            reason = normalized_reason,
            metadata_json = metadata,
        }, function(is_transaction_success, transaction_row, transaction_error)
            if not is_transaction_success then
                Console.Log(
                    "[gr_economy][service] Money operation failed reason=%s character_id=%s wallet=%s amount=%s.",
                    tostring(transaction_error or "transaction-insert-failed"),
                    tostring(normalized_character_id),
                    tostring(normalized_wallet),
                    tostring(normalized_amount)
                )
                callback(false, nil, transaction_error or "transaction-insert-failed")
                return
            end

            Console.Log(
                "[gr_economy][service] Money credited character_id=%s wallet=%s amount=%s reason=%s.",
                tostring(normalized_character_id),
                tostring(normalized_wallet),
                tostring(normalized_amount),
                tostring(normalized_reason)
            )

            callback(true, {
                balance = money_row,
                transaction = transaction_row,
            }, nil)
        end)
    end)
end

function EconomyService:RemoveMoney(character_id, wallet, amount, reason, metadata, callback)
    local normalized_character_id = normalize_positive_integer(character_id)
    local normalized_wallet = normalize_wallet(wallet)
    local normalized_amount = normalize_amount(amount)
    local normalized_reason = normalize_reason(reason)

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if self.repository == nil then
        return callback_repository_missing(callback)
    end

    if normalized_character_id == nil then
        callback(false, nil, "character-id-required")
        return true
    end

    if normalized_wallet == nil then
        callback(false, nil, "wallet-invalid")
        return true
    end

    if normalized_amount == nil then
        callback(false, nil, "amount-invalid")
        return true
    end

    return self.repository:GetCharacterMoney(normalized_character_id, function(is_balance_success, money_row, balance_error)
        if not is_balance_success then
            Console.Log(
                "[gr_economy][service] Money operation failed reason=%s character_id=%s wallet=%s amount=%s.",
                tostring(balance_error),
                tostring(normalized_character_id),
                tostring(normalized_wallet),
                tostring(normalized_amount)
            )
            callback(false, nil, balance_error)
            return
        end

        if money_row == nil then
            callback(false, nil, "character-not-found")
            return
        end

        local current_balance = normalized_wallet == "cash" and (money_row.cash or 0) or (money_row.bank or 0)

        if current_balance < normalized_amount then
            Console.Log(
                "[gr_economy][service] Money operation failed reason=%s character_id=%s wallet=%s amount=%s.",
                "insufficient-funds",
                tostring(normalized_character_id),
                tostring(normalized_wallet),
                tostring(normalized_amount)
            )
            callback(false, nil, "insufficient-funds")
            return
        end

        self.repository:UpdateWallet(normalized_character_id, normalized_wallet, -normalized_amount, function(is_update_success, updated_row, update_error)
            if not is_update_success or updated_row == nil then
                Console.Log(
                    "[gr_economy][service] Money operation failed reason=%s character_id=%s wallet=%s amount=%s.",
                    tostring(update_error or "wallet-update-failed"),
                    tostring(normalized_character_id),
                    tostring(normalized_wallet),
                    tostring(normalized_amount)
                )
                callback(false, nil, update_error or "wallet-update-failed")
                return
            end

            self.repository:InsertTransaction({
                character_id = normalized_character_id,
                amount = normalized_amount,
                currency = "credits",
                wallet = normalized_wallet,
                type = "debit",
                reason = normalized_reason,
                metadata_json = metadata,
            }, function(is_transaction_success, transaction_row, transaction_error)
                if not is_transaction_success then
                    Console.Log(
                        "[gr_economy][service] Money operation failed reason=%s character_id=%s wallet=%s amount=%s.",
                        tostring(transaction_error or "transaction-insert-failed"),
                        tostring(normalized_character_id),
                        tostring(normalized_wallet),
                        tostring(normalized_amount)
                    )
                    callback(false, nil, transaction_error or "transaction-insert-failed")
                    return
                end

                Console.Log(
                    "[gr_economy][service] Money debited character_id=%s wallet=%s amount=%s reason=%s.",
                    tostring(normalized_character_id),
                    tostring(normalized_wallet),
                    tostring(normalized_amount),
                    tostring(normalized_reason)
                )

                callback(true, {
                    balance = updated_row,
                    transaction = transaction_row,
                }, nil)
            end)
        end)
    end)
end

function EconomyService:TransferMoney(from_character_id, to_character_id, wallet, amount, reason, callback)
    local normalized_from_character_id = normalize_positive_integer(from_character_id)
    local normalized_to_character_id = normalize_positive_integer(to_character_id)
    local normalized_wallet = normalize_wallet(wallet)
    local normalized_amount = normalize_amount(amount)
    local normalized_reason = normalize_reason(reason)
    local outgoing_metadata = nil
    local incoming_metadata = nil

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if self.repository == nil then
        return callback_repository_missing(callback)
    end

    if normalized_from_character_id == nil or normalized_to_character_id == nil then
        if normalized_from_character_id == nil then
            callback(false, nil, "invalid-source-character")
            return true
        end

        callback(false, nil, "invalid-target-character")
        return true
    end

    if normalized_from_character_id == normalized_to_character_id then
        callback(false, nil, "same-character")
        return true
    end

    if normalized_wallet == nil then
        callback(false, nil, "invalid-wallet")
        return true
    end

    if normalized_amount == nil then
        callback(false, nil, "invalid-amount")
        return true
    end

    outgoing_metadata = {
        direction = "out",
        target_character_id = normalized_to_character_id,
    }

    incoming_metadata = {
        direction = "in",
        source_character_id = normalized_from_character_id,
    }

    return self.repository:TransferMoneyAtomic(
        normalized_from_character_id,
        normalized_to_character_id,
        normalized_wallet,
        normalized_amount,
        normalized_reason,
        outgoing_metadata,
        incoming_metadata,
        function(is_transfer_success, transfer_result, transfer_error)
            if not is_transfer_success then
                Console.Log(
                    "[gr_economy][service] Transfer failed reason=%s from_character_id=%s to_character_id=%s wallet=%s amount=%s.",
                    tostring(transfer_error or "database-error"),
                    tostring(normalized_from_character_id),
                    tostring(normalized_to_character_id),
                    tostring(normalized_wallet),
                    tostring(normalized_amount)
                )
                callback(false, nil, "database-error")
                return
            end

            if transfer_result == nil then
                Console.Log(
                    "[gr_economy][service] Transfer failed reason=%s from_character_id=%s to_character_id=%s wallet=%s amount=%s.",
                    "transfer-result-missing",
                    tostring(normalized_from_character_id),
                    tostring(normalized_to_character_id),
                    tostring(normalized_wallet),
                    tostring(normalized_amount)
                )
                callback(false, nil, "database-error")
                return
            end

            if transfer_result.source_exists ~= true then
                callback(false, nil, "invalid-source-character")
                return
            end

            if transfer_result.target_exists ~= true then
                callback(false, nil, "invalid-target-character")
                return
            end

            if transfer_result.source_debited ~= true then
                Console.Log(
                    "[gr_economy][service] Transfer failed reason=%s from_character_id=%s to_character_id=%s wallet=%s amount=%s.",
                    "insufficient-funds",
                    tostring(normalized_from_character_id),
                    tostring(normalized_to_character_id),
                    tostring(normalized_wallet),
                    tostring(normalized_amount)
                )
                callback(false, nil, "insufficient-funds")
                return
            end

            if transfer_result.target_credited ~= true
                or transfer_result.outgoing_transaction == nil
                or transfer_result.outgoing_transaction.id == nil
                or transfer_result.incoming_transaction == nil
                or transfer_result.incoming_transaction.id == nil
            then
                Console.Log(
                    "[gr_economy][service] Transfer failed reason=%s from_character_id=%s to_character_id=%s wallet=%s amount=%s.",
                    "transfer-incomplete",
                    tostring(normalized_from_character_id),
                    tostring(normalized_to_character_id),
                    tostring(normalized_wallet),
                    tostring(normalized_amount)
                )
                callback(false, nil, "transfer-incomplete")
                return
            end

            Console.Log(
                "[gr_economy][service] Money transferred from_character_id=%s to_character_id=%s wallet=%s amount=%s reason=%s.",
                tostring(normalized_from_character_id),
                tostring(normalized_to_character_id),
                tostring(normalized_wallet),
                tostring(normalized_amount),
                tostring(normalized_reason)
            )

            callback(true, {
                from_balance = transfer_result.from_balance,
                to_balance = transfer_result.to_balance,
                outgoing_transaction = transfer_result.outgoing_transaction,
                incoming_transaction = transfer_result.incoming_transaction,
            }, nil)
        end
    )
end

function EconomyService:ListTransactions(character_id, limit, callback)
    local normalized_character_id = normalize_positive_integer(character_id)
    local normalized_limit = normalize_limit(limit)

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if self.repository == nil then
        return callback_repository_missing(callback)
    end

    if normalized_character_id == nil then
        callback(false, nil, "character-id-required")
        return true
    end

    return self.repository:ListTransactions(normalized_character_id, normalized_limit, callback)
end

GREconomy.Server.EconomyServiceClass = EconomyService

return EconomyService

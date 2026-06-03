GREconomy = GREconomy or {}
GREconomy.Server = GREconomy.Server or {}

local EconomyRepository = {}
EconomyRepository.__index = EconomyRepository

local SELECT_CHARACTER_MONEY_QUERY = [[
    SELECT
        id,
        money_cash,
        money_bank
    FROM characters
    WHERE id = :0
    LIMIT 1
]]

local UPDATE_CHARACTER_MONEY_QUERY = [[
    UPDATE characters
    SET
        money_cash = :1,
        money_bank = :2,
        updated_at = NOW()
    WHERE id = :0
    RETURNING
        id,
        money_cash,
        money_bank
]]

local UPDATE_CASH_WALLET_QUERY = [[
    UPDATE characters
    SET
        money_cash = money_cash + :1,
        updated_at = NOW()
    WHERE id = :0 AND money_cash + :1 >= 0
    RETURNING
        id,
        money_cash,
        money_bank
]]

local UPDATE_BANK_WALLET_QUERY = [[
    UPDATE characters
    SET
        money_bank = money_bank + :1,
        updated_at = NOW()
    WHERE id = :0 AND money_bank + :1 >= 0
    RETURNING
        id,
        money_cash,
        money_bank
]]

local INSERT_TRANSACTION_QUERY = [[
    INSERT INTO bank_transactions (
        character_id,
        target_character_id,
        amount,
        currency,
        wallet,
        type,
        reason,
        metadata_json
    )
    VALUES (
        :0,
        :1,
        :2,
        :3,
        :4,
        :5,
        :6,
        CAST(:7 AS JSONB)
    )
    RETURNING
        id,
        character_id,
        target_character_id,
        amount,
        currency,
        wallet,
        type,
        reason,
        metadata_json::TEXT AS metadata_json,
        created_at
]]

local SELECT_TRANSACTIONS_QUERY = [[
    SELECT
        id,
        character_id,
        target_character_id,
        amount,
        currency,
        wallet,
        type,
        reason,
        metadata_json::TEXT AS metadata_json,
        created_at
    FROM bank_transactions
    WHERE character_id = :0 OR target_character_id = :1
    ORDER BY id DESC
    LIMIT :2
]]

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

local function normalize_non_negative_integer(value, fallback)
    if type(value) == "number" then
        if value < 0 or value % 1 ~= 0 then
            return fallback
        end

        return math.floor(value)
    end

    if type(value) == "string" and value:match("^%d+$") ~= nil then
        local parsed_value = tonumber(value)

        if parsed_value ~= nil and parsed_value >= 0 then
            return math.floor(parsed_value)
        end
    end

    return fallback
end

local function normalize_integer(value, fallback)
    if type(value) == "number" then
        if value % 1 ~= 0 then
            return fallback
        end

        return math.floor(value)
    end

    if type(value) == "string" and value:match("^[+-]?%d+$") ~= nil then
        local parsed_value = tonumber(value)

        if parsed_value ~= nil then
            return math.floor(parsed_value)
        end
    end

    return fallback
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

local function normalize_transaction_type(transaction_type)
    local normalized_type = trim_string(transaction_type)

    if normalized_type == nil then
        return nil
    end

    normalized_type = string.lower(normalized_type)

    if normalized_type ~= "credit"
        and normalized_type ~= "debit"
        and normalized_type ~= "transfer_in"
        and normalized_type ~= "transfer_out"
        and normalized_type ~= "adjustment"
    then
        return nil
    end

    return normalized_type
end

local function normalize_currency(currency)
    local normalized_currency = trim_string(currency)

    if normalized_currency == nil then
        return "credits"
    end

    return string.lower(normalized_currency)
end

local function encode_metadata_json(metadata)
    if metadata == nil then
        return "{}"
    end

    if type(metadata) == "string" then
        return trim_string(metadata) or "{}"
    end

    if type(JSON) == "table" and type(JSON.Stringify) == "function" then
        local is_encoded, encoded_value = pcall(JSON.Stringify, metadata)

        if is_encoded and type(encoded_value) == "string" and encoded_value ~= "" then
            return encoded_value
        end
    end

    return "{}"
end

local function normalize_money_row(row)
    local character_id = nil

    if type(row) ~= "table" then
        return nil
    end

    character_id = normalize_positive_integer(row.id)

    if character_id == nil then
        return nil
    end

    return {
        character_id = character_id,
        cash = normalize_non_negative_integer(row.money_cash, 0),
        bank = normalize_non_negative_integer(row.money_bank, 0),
    }
end

local function normalize_transaction_row(row)
    local transaction_id = nil
    local character_id = nil
    local wallet = nil
    local transaction_type = nil

    if type(row) ~= "table" then
        return nil
    end

    transaction_id = normalize_positive_integer(row.id)
    character_id = normalize_positive_integer(row.character_id)
    wallet = normalize_wallet(row.wallet)
    transaction_type = normalize_transaction_type(row.type)

    if transaction_id == nil or character_id == nil or wallet == nil or transaction_type == nil then
        return nil
    end

    return {
        id = transaction_id,
        character_id = character_id,
        target_character_id = normalize_positive_integer(row.target_character_id),
        amount = normalize_non_negative_integer(row.amount, 0),
        currency = normalize_currency(row.currency),
        wallet = wallet,
        type = transaction_type,
        reason = trim_string(row.reason) or "unspecified",
        metadata_json = trim_string(row.metadata_json) or "{}",
        created_at = row.created_at,
    }
end

local function normalize_rows(rows, normalizer)
    local normalized_rows = {}

    for _, row in ipairs(rows or {}) do
        local normalized_row = normalizer(row)

        if normalized_row ~= nil then
            normalized_rows[#normalized_rows + 1] = normalized_row
        end
    end

    return normalized_rows
end

function EconomyRepository.Create(database_service)
    local self = setmetatable({}, EconomyRepository)

    self.database_service = database_service

    return self
end

function EconomyRepository:Connect(callback, reason)
    local is_connected = false
    local database_or_error = nil

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if self.database_service == nil then
        Console.Log(
            "[gr_economy][repository] Database service unavailable during %s.",
            tostring(reason or "economy-call")
        )
        callback(false, nil, "database-service-missing")
        return true
    end

    is_connected, database_or_error = self.database_service:Connect()

    if not is_connected then
        Console.Log(
            "[gr_economy][repository] Database connection failed during %s with error=%s.",
            tostring(reason or "economy-call"),
            tostring(database_or_error)
        )
        callback(false, nil, database_or_error)
        return true
    end

    callback(true, database_or_error, nil)
    return true
end

function EconomyRepository:GetCharacterMoney(character_id, callback)
    local normalized_character_id = normalize_positive_integer(character_id)

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if normalized_character_id == nil then
        callback(false, nil, "character-id-required")
        return true
    end

    return self:Connect(function(is_connected, database_or_error, error)
        if not is_connected then
            callback(false, nil, error)
            return
        end

        database_or_error:SelectAsync(SELECT_CHARACTER_MONEY_QUERY, function(rows, select_error)
            local money_rows = nil

            if select_error ~= nil then
                callback(false, nil, select_error)
                return
            end

            money_rows = normalize_rows(rows, normalize_money_row)
            callback(true, money_rows[1], nil)
        end, normalized_character_id)
    end, "economy-get-character-money")
end

function EconomyRepository:SetCharacterMoney(character_id, money_cash, money_bank, callback)
    local normalized_character_id = normalize_positive_integer(character_id)
    local normalized_money_cash = normalize_non_negative_integer(money_cash, nil)
    local normalized_money_bank = normalize_non_negative_integer(money_bank, nil)

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if normalized_character_id == nil then
        callback(false, nil, "character-id-required")
        return true
    end

    if normalized_money_cash == nil or normalized_money_bank == nil then
        callback(false, nil, "wallet-balance-required")
        return true
    end

    return self:Connect(function(is_connected, database_or_error, error)
        if not is_connected then
            callback(false, nil, error)
            return
        end

        database_or_error:SelectAsync(UPDATE_CHARACTER_MONEY_QUERY, function(rows, update_error)
            local money_rows = nil

            if update_error ~= nil then
                callback(false, nil, update_error)
                return
            end

            money_rows = normalize_rows(rows, normalize_money_row)
            callback(true, money_rows[1], nil)
        end, normalized_character_id, normalized_money_cash, normalized_money_bank)
    end, "economy-set-character-money")
end

function EconomyRepository:UpdateWallet(character_id, wallet, amount_delta, callback)
    local normalized_character_id = normalize_positive_integer(character_id)
    local normalized_wallet = normalize_wallet(wallet)
    local normalized_amount_delta = normalize_integer(amount_delta, nil)
    local update_query = nil

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if normalized_character_id == nil then
        callback(false, nil, "character-id-required")
        return true
    end

    if normalized_wallet == nil then
        callback(false, nil, "wallet-invalid")
        return true
    end

    if normalized_amount_delta == nil or normalized_amount_delta == 0 then
        callback(false, nil, "amount-delta-required")
        return true
    end

    update_query = normalized_wallet == "cash" and UPDATE_CASH_WALLET_QUERY or UPDATE_BANK_WALLET_QUERY

    return self:Connect(function(is_connected, database_or_error, error)
        if not is_connected then
            callback(false, nil, error)
            return
        end

        database_or_error:SelectAsync(update_query, function(rows, update_error)
            local money_rows = nil

            if update_error ~= nil then
                callback(false, nil, update_error)
                return
            end

            money_rows = normalize_rows(rows, normalize_money_row)
            callback(true, money_rows[1], nil)
        end, normalized_character_id, normalized_amount_delta)
    end, "economy-update-wallet")
end

function EconomyRepository:InsertTransaction(transaction, callback)
    local normalized_character_id = normalize_positive_integer(transaction and transaction.character_id)
    local normalized_target_character_id = normalize_positive_integer(transaction and transaction.target_character_id)
    local normalized_amount = normalize_non_negative_integer(transaction and transaction.amount, nil)
    local normalized_currency = normalize_currency(transaction and transaction.currency)
    local normalized_wallet = normalize_wallet(transaction and transaction.wallet)
    local normalized_type = normalize_transaction_type(transaction and transaction.type)
    local normalized_reason = trim_string(transaction and transaction.reason) or "unspecified"
    local normalized_metadata_json = encode_metadata_json(transaction and transaction.metadata_json)

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if normalized_character_id == nil then
        callback(false, nil, "character-id-required")
        return true
    end

    if normalized_amount == nil then
        callback(false, nil, "transaction-amount-required")
        return true
    end

    if normalized_wallet == nil then
        callback(false, nil, "wallet-invalid")
        return true
    end

    if normalized_type == nil then
        callback(false, nil, "transaction-type-invalid")
        return true
    end

    return self:Connect(function(is_connected, database_or_error, error)
        if not is_connected then
            callback(false, nil, error)
            return
        end

        database_or_error:SelectAsync(INSERT_TRANSACTION_QUERY, function(rows, insert_error)
            local transaction_rows = nil

            if insert_error ~= nil then
                callback(false, nil, insert_error)
                return
            end

            transaction_rows = normalize_rows(rows, normalize_transaction_row)
            callback(true, transaction_rows[1], nil)
        end,
            normalized_character_id,
            normalized_target_character_id,
            normalized_amount,
            normalized_currency,
            normalized_wallet,
            normalized_type,
            normalized_reason,
            normalized_metadata_json
        )
    end, "economy-insert-transaction")
end

function EconomyRepository:ListTransactions(character_id, limit, callback)
    local normalized_character_id = normalize_positive_integer(character_id)
    local normalized_limit = normalize_positive_integer(limit) or 10

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if normalized_character_id == nil then
        callback(false, nil, "character-id-required")
        return true
    end

    if normalized_limit > 50 then
        normalized_limit = 50
    end

    return self:Connect(function(is_connected, database_or_error, error)
        if not is_connected then
            callback(false, nil, error)
            return
        end

        database_or_error:SelectAsync(SELECT_TRANSACTIONS_QUERY, function(rows, select_error)
            if select_error ~= nil then
                callback(false, nil, select_error)
                return
            end

            callback(true, normalize_rows(rows, normalize_transaction_row), nil)
        end, normalized_character_id, normalized_character_id, normalized_limit)
    end, "economy-list-transactions")
end

GREconomy.Server.EconomyRepositoryClass = EconomyRepository

return EconomyRepository

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

local SELECT_CHARACTER_SALARY_AFFILIATION_QUERY = [[
    SELECT
        characters.id,
        characters.faction_id,
        characters.rank_id,
        factions.type AS faction_key
    FROM characters
    LEFT JOIN factions
        ON factions.id = characters.faction_id
    WHERE characters.id = :0
    LIMIT 1
]]

local SELECT_SALARY_RULE_FOR_CHARACTER_QUERY = [[
    SELECT
        id,
        key,
        label,
        faction_id,
        faction_key,
        rank_id,
        wallet,
        amount,
        cooldown_seconds,
        is_active,
        created_at,
        updated_at
    FROM economy_salary_rules
    WHERE is_active = TRUE
        AND (
            (faction_id IS NOT NULL AND faction_id = NULLIF(:0, 0))
            OR (
                faction_id IS NULL
                AND faction_key IS NOT NULL
                AND faction_key = NULLIF(:1, '')
            )
        )
        AND (rank_id IS NULL OR rank_id = NULLIF(:2, 0))
    ORDER BY
        CASE WHEN rank_id = NULLIF(:3, 0) THEN 0 ELSE 1 END,
        CASE WHEN faction_id IS NOT NULL THEN 0 ELSE 1 END,
        id ASC
    LIMIT 1
]]

local SELECT_SALARY_RULES_QUERY = [[
    SELECT
        id,
        key,
        label,
        faction_id,
        faction_key,
        rank_id,
        wallet,
        amount,
        cooldown_seconds,
        is_active,
        created_at,
        updated_at
    FROM economy_salary_rules
    ORDER BY is_active DESC, key ASC, id ASC
]]

local SELECT_SALARY_CLAIM_QUERY = [[
    SELECT
        character_id,
        salary_rule_id,
        last_claimed_at,
        EXTRACT(EPOCH FROM last_claimed_at) AS last_claimed_epoch,
        claim_count,
        updated_at
    FROM character_salary_claims
    WHERE character_id = :0
        AND salary_rule_id = :1
    LIMIT 1
]]

local UPSERT_SALARY_CLAIM_QUERY = [[
    INSERT INTO character_salary_claims (
        character_id,
        salary_rule_id,
        last_claimed_at,
        claim_count,
        updated_at
    )
    VALUES (
        :0,
        :1,
        NOW(),
        1,
        NOW()
    )
    ON CONFLICT (character_id, salary_rule_id) DO UPDATE
    SET
        last_claimed_at = NOW(),
        claim_count = character_salary_claims.claim_count + 1,
        updated_at = NOW()
    RETURNING
        character_id,
        salary_rule_id,
        last_claimed_at,
        EXTRACT(EPOCH FROM last_claimed_at) AS last_claimed_epoch,
        claim_count,
        updated_at
]]

local ATOMIC_TRANSFER_CASH_QUERY = [[
    WITH source_row AS (
        SELECT
            id,
            money_cash,
            money_bank
        FROM characters
        WHERE id = :0
        LIMIT 1
    ),
    target_row AS (
        SELECT
            id,
            money_cash,
            money_bank
        FROM characters
        WHERE id = :1
        LIMIT 1
    ),
    debit_source AS (
        UPDATE characters
        SET
            money_cash = money_cash - :2,
            updated_at = NOW()
        WHERE id = :3
            AND EXISTS (SELECT 1 FROM target_row)
            AND money_cash >= :4
        RETURNING
            id,
            money_cash,
            money_bank
    ),
    credit_target AS (
        UPDATE characters
        SET
            money_cash = money_cash + :5,
            updated_at = NOW()
        WHERE id = :6
            AND EXISTS (SELECT 1 FROM debit_source)
        RETURNING
            id,
            money_cash,
            money_bank
    ),
    outgoing_transaction AS (
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
        SELECT
            :7,
            :8,
            :9,
            :10,
            :11,
            :12,
            :13,
            CAST(:14 AS JSONB)
        FROM credit_target
        RETURNING
            id
    ),
    incoming_transaction AS (
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
        SELECT
            :15,
            :16,
            :17,
            :18,
            :19,
            :20,
            :21,
            CAST(:22 AS JSONB)
        FROM outgoing_transaction
        RETURNING
            id
    )
    SELECT
        CASE WHEN EXISTS (SELECT 1 FROM source_row) THEN TRUE ELSE FALSE END AS source_exists,
        CASE WHEN EXISTS (SELECT 1 FROM target_row) THEN TRUE ELSE FALSE END AS target_exists,
        CASE WHEN EXISTS (SELECT 1 FROM debit_source) THEN TRUE ELSE FALSE END AS source_debited,
        CASE WHEN EXISTS (SELECT 1 FROM credit_target) THEN TRUE ELSE FALSE END AS target_credited,
        (SELECT money_cash FROM debit_source LIMIT 1) AS from_money_cash,
        (SELECT money_bank FROM debit_source LIMIT 1) AS from_money_bank,
        (SELECT money_cash FROM credit_target LIMIT 1) AS to_money_cash,
        (SELECT money_bank FROM credit_target LIMIT 1) AS to_money_bank,
        (SELECT id FROM outgoing_transaction LIMIT 1) AS outgoing_transaction_id,
        (SELECT id FROM incoming_transaction LIMIT 1) AS incoming_transaction_id
]]

local ATOMIC_TRANSFER_BANK_QUERY = [[
    WITH source_row AS (
        SELECT
            id,
            money_cash,
            money_bank
        FROM characters
        WHERE id = :0
        LIMIT 1
    ),
    target_row AS (
        SELECT
            id,
            money_cash,
            money_bank
        FROM characters
        WHERE id = :1
        LIMIT 1
    ),
    debit_source AS (
        UPDATE characters
        SET
            money_bank = money_bank - :2,
            updated_at = NOW()
        WHERE id = :3
            AND EXISTS (SELECT 1 FROM target_row)
            AND money_bank >= :4
        RETURNING
            id,
            money_cash,
            money_bank
    ),
    credit_target AS (
        UPDATE characters
        SET
            money_bank = money_bank + :5,
            updated_at = NOW()
        WHERE id = :6
            AND EXISTS (SELECT 1 FROM debit_source)
        RETURNING
            id,
            money_cash,
            money_bank
    ),
    outgoing_transaction AS (
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
        SELECT
            :7,
            :8,
            :9,
            :10,
            :11,
            :12,
            :13,
            CAST(:14 AS JSONB)
        FROM credit_target
        RETURNING
            id
    ),
    incoming_transaction AS (
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
        SELECT
            :15,
            :16,
            :17,
            :18,
            :19,
            :20,
            :21,
            CAST(:22 AS JSONB)
        FROM outgoing_transaction
        RETURNING
            id
    )
    SELECT
        CASE WHEN EXISTS (SELECT 1 FROM source_row) THEN TRUE ELSE FALSE END AS source_exists,
        CASE WHEN EXISTS (SELECT 1 FROM target_row) THEN TRUE ELSE FALSE END AS target_exists,
        CASE WHEN EXISTS (SELECT 1 FROM debit_source) THEN TRUE ELSE FALSE END AS source_debited,
        CASE WHEN EXISTS (SELECT 1 FROM credit_target) THEN TRUE ELSE FALSE END AS target_credited,
        (SELECT money_cash FROM debit_source LIMIT 1) AS from_money_cash,
        (SELECT money_bank FROM debit_source LIMIT 1) AS from_money_bank,
        (SELECT money_cash FROM credit_target LIMIT 1) AS to_money_cash,
        (SELECT money_bank FROM credit_target LIMIT 1) AS to_money_bank,
        (SELECT id FROM outgoing_transaction LIMIT 1) AS outgoing_transaction_id,
        (SELECT id FROM incoming_transaction LIMIT 1) AS incoming_transaction_id
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

local function normalize_boolean(value, fallback)
    if type(value) == "boolean" then
        return value
    end

    local string_value = trim_string(value)

    if string_value ~= nil then
        local lowered_value = string.lower(string_value)

        if lowered_value == "true" or lowered_value == "t" or lowered_value == "1" then
            return true
        end

        if lowered_value == "false" or lowered_value == "f" or lowered_value == "0" then
            return false
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

local function normalize_salary_affiliation_row(row)
    local character_id = nil

    if type(row) ~= "table" then
        return nil
    end

    character_id = normalize_positive_integer(row.id)

    if character_id == nil then
        return nil
    end

    return {
        id = character_id,
        faction_id = normalize_positive_integer(row.faction_id),
        rank_id = normalize_positive_integer(row.rank_id),
        faction_key = trim_string(row.faction_key),
    }
end

local function normalize_salary_rule_row(row)
    local salary_rule_id = nil

    if type(row) ~= "table" then
        return nil
    end

    salary_rule_id = normalize_positive_integer(row.id)

    if salary_rule_id == nil then
        return nil
    end

    return {
        id = salary_rule_id,
        key = trim_string(row.key),
        label = trim_string(row.label),
        faction_id = normalize_positive_integer(row.faction_id),
        faction_key = trim_string(row.faction_key),
        rank_id = normalize_positive_integer(row.rank_id),
        wallet = normalize_wallet(row.wallet),
        amount = normalize_positive_integer(row.amount),
        cooldown_seconds = normalize_positive_integer(row.cooldown_seconds),
        is_active = normalize_boolean(row.is_active, false),
        created_at = row.created_at,
        updated_at = row.updated_at,
    }
end

local function normalize_salary_claim_row(row)
    local character_id = nil
    local salary_rule_id = nil

    if type(row) ~= "table" then
        return nil
    end

    character_id = normalize_positive_integer(row.character_id)
    salary_rule_id = normalize_positive_integer(row.salary_rule_id)

    if character_id == nil or salary_rule_id == nil then
        return nil
    end

    return {
        character_id = character_id,
        salary_rule_id = salary_rule_id,
        last_claimed_at = row.last_claimed_at,
        last_claimed_epoch = tonumber(row.last_claimed_epoch) or 0,
        claim_count = normalize_non_negative_integer(row.claim_count, 0),
        updated_at = row.updated_at,
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

local function normalize_transfer_result_row(row, from_character_id, to_character_id)
    local normalized_from_character_id = normalize_positive_integer(from_character_id)
    local normalized_to_character_id = normalize_positive_integer(to_character_id)

    if type(row) ~= "table" then
        return nil
    end

    if normalized_from_character_id == nil or normalized_to_character_id == nil then
        return nil
    end

    return {
        source_exists = normalize_boolean(row.source_exists, false),
        target_exists = normalize_boolean(row.target_exists, false),
        source_debited = normalize_boolean(row.source_debited, false),
        target_credited = normalize_boolean(row.target_credited, false),
        from_balance = {
            id = normalized_from_character_id,
            cash = normalize_non_negative_integer(row.from_money_cash, 0),
            bank = normalize_non_negative_integer(row.from_money_bank, 0),
        },
        to_balance = {
            id = normalized_to_character_id,
            cash = normalize_non_negative_integer(row.to_money_cash, 0),
            bank = normalize_non_negative_integer(row.to_money_bank, 0),
        },
        outgoing_transaction = {
            id = normalize_positive_integer(row.outgoing_transaction_id),
        },
        incoming_transaction = {
            id = normalize_positive_integer(row.incoming_transaction_id),
        },
    }
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

function EconomyRepository:GetSalaryRuleForCharacter(character_id, callback)
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

        database_or_error:SelectAsync(SELECT_CHARACTER_SALARY_AFFILIATION_QUERY, function(character_rows, character_error)
            local normalized_character_rows = nil
            local affiliation_row = nil
            local faction_id = 0
            local faction_key = ""
            local rank_id = 0

            if character_error ~= nil then
                callback(false, nil, character_error)
                return
            end

            normalized_character_rows = normalize_rows(character_rows, normalize_salary_affiliation_row)
            affiliation_row = normalized_character_rows[1]

            if affiliation_row == nil then
                callback(true, nil, "character-not-found")
                return
            end

            faction_id = affiliation_row.faction_id or 0
            faction_key = affiliation_row.faction_key or ""
            rank_id = affiliation_row.rank_id or 0

            database_or_error:SelectAsync(SELECT_SALARY_RULE_FOR_CHARACTER_QUERY, function(rule_rows, rule_error)
                local normalized_rule_rows = nil

                if rule_error ~= nil then
                    callback(false, nil, rule_error)
                    return
                end

                normalized_rule_rows = normalize_rows(rule_rows, normalize_salary_rule_row)
                callback(true, normalized_rule_rows[1], nil)
            end, faction_id, faction_key, rank_id, rank_id)
        end, normalized_character_id)
    end, "economy-get-salary-rule-for-character")
end

function EconomyRepository:GetSalaryClaim(character_id, salary_rule_id, callback)
    local normalized_character_id = normalize_positive_integer(character_id)
    local normalized_salary_rule_id = normalize_positive_integer(salary_rule_id)

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if normalized_character_id == nil or normalized_salary_rule_id == nil then
        callback(false, nil, "salary-claim-key-required")
        return true
    end

    return self:Connect(function(is_connected, database_or_error, error)
        if not is_connected then
            callback(false, nil, error)
            return
        end

        database_or_error:SelectAsync(SELECT_SALARY_CLAIM_QUERY, function(rows, select_error)
            local normalized_rows = nil

            if select_error ~= nil then
                callback(false, nil, select_error)
                return
            end

            normalized_rows = normalize_rows(rows, normalize_salary_claim_row)
            callback(true, normalized_rows[1], nil)
        end, normalized_character_id, normalized_salary_rule_id)
    end, "economy-get-salary-claim")
end

function EconomyRepository:UpsertSalaryClaim(character_id, salary_rule_id, callback)
    local normalized_character_id = normalize_positive_integer(character_id)
    local normalized_salary_rule_id = normalize_positive_integer(salary_rule_id)

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if normalized_character_id == nil or normalized_salary_rule_id == nil then
        callback(false, nil, "salary-claim-key-required")
        return true
    end

    return self:Connect(function(is_connected, database_or_error, error)
        if not is_connected then
            callback(false, nil, error)
            return
        end

        database_or_error:SelectAsync(UPSERT_SALARY_CLAIM_QUERY, function(rows, upsert_error)
            local normalized_rows = nil

            if upsert_error ~= nil then
                callback(false, nil, upsert_error)
                return
            end

            normalized_rows = normalize_rows(rows, normalize_salary_claim_row)
            callback(true, normalized_rows[1], nil)
        end, normalized_character_id, normalized_salary_rule_id)
    end, "economy-upsert-salary-claim")
end

function EconomyRepository:ListSalaryRules(callback)
    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    return self:Connect(function(is_connected, database_or_error, error)
        if not is_connected then
            callback(false, nil, error)
            return
        end

        database_or_error:SelectAsync(SELECT_SALARY_RULES_QUERY, function(rows, select_error)
            if select_error ~= nil then
                callback(false, nil, select_error)
                return
            end

            callback(true, normalize_rows(rows, normalize_salary_rule_row), nil)
        end)
    end, "economy-list-salary-rules")
end

function EconomyRepository:TransferMoneyAtomic(from_character_id, to_character_id, wallet, amount, reason, outgoing_metadata_json, incoming_metadata_json, callback)
    local normalized_from_character_id = normalize_positive_integer(from_character_id)
    local normalized_to_character_id = normalize_positive_integer(to_character_id)
    local normalized_wallet = normalize_wallet(wallet)
    local normalized_amount = normalize_positive_integer(amount)
    local normalized_reason = trim_string(reason) or "unspecified"
    local normalized_outgoing_metadata_json = encode_metadata_json(outgoing_metadata_json)
    local normalized_incoming_metadata_json = encode_metadata_json(incoming_metadata_json)
    local transfer_query = nil
    local unpack_values = table.unpack or unpack

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if normalized_from_character_id == nil or normalized_to_character_id == nil then
        callback(false, nil, "character-id-required")
        return true
    end

    if normalized_wallet == nil then
        callback(false, nil, "wallet-invalid")
        return true
    end

    if normalized_amount == nil then
        callback(false, nil, "transfer-amount-required")
        return true
    end

    transfer_query = normalized_wallet == "cash" and ATOMIC_TRANSFER_CASH_QUERY or ATOMIC_TRANSFER_BANK_QUERY

    return self:Connect(function(is_connected, database_or_error, error)
        if not is_connected then
            callback(false, nil, error)
            return
        end

        local query_parameters = {
            normalized_from_character_id,
            normalized_to_character_id,
            normalized_amount,
            normalized_from_character_id,
            normalized_amount,
            normalized_amount,
            normalized_to_character_id,
            normalized_from_character_id,
            normalized_to_character_id,
            normalized_amount,
            "credits",
            normalized_wallet,
            "transfer_out",
            normalized_reason,
            normalized_outgoing_metadata_json,
            normalized_to_character_id,
            normalized_from_character_id,
            normalized_amount,
            "credits",
            normalized_wallet,
            "transfer_in",
            normalized_reason,
            normalized_incoming_metadata_json,
        }

        database_or_error:SelectAsync(transfer_query, function(rows, select_error)
            local normalized_rows = nil

            if select_error ~= nil then
                callback(false, nil, select_error)
                return
            end

            normalized_rows = normalize_rows(rows, function(row)
                return normalize_transfer_result_row(row, normalized_from_character_id, normalized_to_character_id)
            end)

            callback(true, normalized_rows[1], nil)
        end, unpack_values(query_parameters))
    end, "economy-transfer-money-atomic")
end

GREconomy.Server.EconomyRepositoryClass = EconomyRepository

return EconomyRepository

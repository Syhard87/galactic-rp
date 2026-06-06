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

local function normalize_diagnostic_limit(limit)
    local normalized_limit = normalize_positive_integer(limit) or 10

    if normalized_limit > 25 then
        return 25
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

function EconomyService:ClaimSalary(character_id, callback)
    local normalized_character_id = normalize_positive_integer(character_id)

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if self.repository == nil then
        return callback_repository_missing(callback)
    end

    if normalized_character_id == nil then
        callback(false, nil, "character-not-found")
        return true
    end

    return self.repository:GetSalaryRuleForCharacter(normalized_character_id, function(is_rule_success, salary_rule, rule_error)
        if not is_rule_success then
            callback(false, nil, "database-error")
            return
        end

        if rule_error == "character-not-found" then
            callback(false, nil, "character-not-found")
            return
        end

        if salary_rule == nil then
            callback(false, nil, "salary-rule-not-found")
            return
        end

        self.repository:GetSalaryClaim(normalized_character_id, salary_rule.id, function(is_claim_success, salary_claim, claim_error)
            if not is_claim_success then
                callback(false, nil, "database-error")
                return
            end

            local current_epoch = os.time()
            local last_claim_epoch = salary_claim and salary_claim.last_claimed_epoch or 0
            local cooldown_seconds = salary_rule.cooldown_seconds or 0
            local remaining_seconds = 0

            if last_claim_epoch > 0 and cooldown_seconds > 0 then
                remaining_seconds = math.max(0, math.floor((last_claim_epoch + cooldown_seconds) - current_epoch))
            end

            if remaining_seconds > 0 then
                callback(false, {
                    salary_rule = salary_rule,
                    remaining_seconds = remaining_seconds,
                    salary_claim = salary_claim,
                }, "salary-on-cooldown")
                return
            end

            local reason = "salary:" .. tostring(salary_rule.key or salary_rule.id)
            local metadata = {
                salary_rule_id = salary_rule.id,
                salary_rule_key = salary_rule.key,
            }

            self:AddMoney(normalized_character_id, salary_rule.wallet, salary_rule.amount, reason, metadata, function(is_payment_success, payment_result, payment_error)
                if not is_payment_success then
                    callback(false, {
                        salary_rule = salary_rule,
                        payment_error = payment_error,
                    }, "payment-failed")
                    return
                end

                self.repository:UpsertSalaryClaim(normalized_character_id, salary_rule.id, function(is_upsert_success, updated_claim, upsert_error)
                    if is_upsert_success and updated_claim ~= nil then
                        Console.Log(
                            "[gr_economy][service] Salary claimed character_id=%s salary_rule_id=%s salary_rule_key=%s wallet=%s amount=%s.",
                            tostring(normalized_character_id),
                            tostring(salary_rule.id),
                            tostring(salary_rule.key),
                            tostring(salary_rule.wallet),
                            tostring(salary_rule.amount)
                        )

                        callback(true, {
                            salary_rule = salary_rule,
                            claim = updated_claim,
                            balance = payment_result and payment_result.balance or nil,
                            transaction = payment_result and payment_result.transaction or nil,
                        }, nil)
                        return
                    end

                    local rollback_reason = "salary-rollback:" .. tostring(salary_rule.key or salary_rule.id)
                    local rollback_metadata = {
                        salary_rule_id = salary_rule.id,
                        salary_rule_key = salary_rule.key,
                        rollback_reason = "claim-update-failed",
                    }

                    self:RemoveMoney(normalized_character_id, salary_rule.wallet, salary_rule.amount, rollback_reason, rollback_metadata, function(is_rollback_success, rollback_result, rollback_error)
                        if is_rollback_success then
                            Console.Log(
                                "[gr_economy][service] Salary rollback completed character_id=%s salary_rule_id=%s salary_rule_key=%s wallet=%s amount=%s.",
                                tostring(normalized_character_id),
                                tostring(salary_rule.id),
                                tostring(salary_rule.key),
                                tostring(salary_rule.wallet),
                                tostring(salary_rule.amount)
                            )

                            callback(false, {
                                salary_rule = salary_rule,
                                claim_error = upsert_error,
                                rollback = rollback_result,
                            }, "claim-update-failed")
                            return
                        end

                        Console.Log(
                            "[gr_economy][service] Salary rollback failed character_id=%s salary_rule_id=%s salary_rule_key=%s wallet=%s amount=%s reason=%s.",
                            tostring(normalized_character_id),
                            tostring(salary_rule.id),
                            tostring(salary_rule.key),
                            tostring(salary_rule.wallet),
                            tostring(salary_rule.amount),
                            tostring(rollback_error or upsert_error or "rollback-failed")
                        )

                        callback(false, {
                            salary_rule = salary_rule,
                            claim_error = upsert_error,
                            rollback_error = rollback_error,
                        }, "rollback-failed")
                    end)
                end)
            end)
        end)
    end)
end

function EconomyService:ListSalaryRules(callback)
    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if self.repository == nil then
        return callback_repository_missing(callback)
    end

    return self.repository:ListSalaryRules(callback)
end

function EconomyService:GetBalanceDiagnostic(character_id, callback)
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

    return self.repository:GetCharacterEconomySnapshot(normalized_character_id, callback)
end

function EconomyService:ListTransactionsDiagnostic(character_id, limit, callback)
    local normalized_character_id = normalize_positive_integer(character_id)
    local normalized_limit = normalize_diagnostic_limit(limit)

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

    return self.repository:ListTransactionsForCharacter(normalized_character_id, normalized_limit, callback)
end

function EconomyService:GetSalaryDiagnostic(character_id, callback)
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

    return self.repository:GetSalaryStatusForCharacter(normalized_character_id, function(is_success, salary_status, error)
        if not is_success then
            callback(false, nil, error)
            return
        end

        if error == "character-not-found" then
            callback(false, nil, "character-not-found")
            return
        end

        if salary_status == nil or salary_status.salary_rule == nil then
            callback(true, {
                character_id = normalized_character_id,
                salary_rule = nil,
                salary_claim = nil,
                cooldown_remaining = 0,
            }, nil)
            return
        end

        local current_epoch = os.time()
        local last_claim_epoch = salary_status.salary_claim and salary_status.salary_claim.last_claimed_epoch or 0
        local cooldown_seconds = salary_status.salary_rule.cooldown_seconds or 0
        local cooldown_remaining = 0

        if last_claim_epoch > 0 and cooldown_seconds > 0 then
            cooldown_remaining = math.max(0, math.floor((last_claim_epoch + cooldown_seconds) - current_epoch))
        end

        salary_status.cooldown_remaining = cooldown_remaining
        callback(true, salary_status, nil)
    end)
end

function EconomyService:GetEconomyHealth(callback)
    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if self.repository == nil then
        return callback_repository_missing(callback)
    end

    return self.repository:GetEconomyHealth(callback)
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

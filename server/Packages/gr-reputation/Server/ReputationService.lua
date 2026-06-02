GRReputation = GRReputation or {}
GRReputation.Server = GRReputation.Server or {}

local ReputationService = {}
ReputationService.__index = ReputationService

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

local function normalize_integer(value)
    if type(value) == "number" then
        if value % 1 ~= 0 then
            return nil
        end

        return math.floor(value)
    end

    if type(value) == "string" and value:match("^[+-]?%d+$") ~= nil then
        local parsed_value = tonumber(value)

        if parsed_value ~= nil then
            return math.floor(parsed_value)
        end
    end

    return nil
end

local function normalize_reputation_key(reputation_key)
    local normalized_reputation_key = trim_string(reputation_key)

    if normalized_reputation_key == nil then
        return nil
    end

    normalized_reputation_key = string.lower(normalized_reputation_key)

    if normalized_reputation_key:match("^[a-z0-9_]+$") == nil then
        return nil
    end

    return normalized_reputation_key
end

local function normalize_reason(reason)
    return trim_string(reason) or "unspecified"
end

local function clamp_value(value, min_value, max_value)
    local normalized_value = normalize_integer(value) or 0
    local normalized_min_value = normalize_integer(min_value) or -1000
    local normalized_max_value = normalize_integer(max_value) or 1000

    if normalized_value < normalized_min_value then
        return normalized_min_value
    end

    if normalized_value > normalized_max_value then
        return normalized_max_value
    end

    return normalized_value
end

local function callback_repository_missing(callback)
    if type(callback) == "function" then
        callback(false, nil, "reputation-repository-missing")
    end

    return true
end

function ReputationService.Create(repository)
    local self = setmetatable({}, ReputationService)

    self.repository = repository

    return self
end

function ReputationService:ComputeRank(value)
    local normalized_value = normalize_integer(value) or 0

    if normalized_value <= -500 then
        return "hostile"
    end

    if normalized_value <= -100 then
        return "unfriendly"
    end

    if normalized_value >= 750 then
        return "trusted"
    end

    if normalized_value >= 250 then
        return "friendly"
    end

    return "neutral"
end

function ReputationService:ListCharacterReputations(character_id, callback)
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

    return self.repository:ListDefinitions(function(is_definitions_success, definition_rows, definitions_error)
        if not is_definitions_success then
            callback(false, nil, definitions_error)
            return
        end

        self.repository:ListCharacterReputations(normalized_character_id, function(is_reputations_success, reputation_rows, reputations_error)
            local reputation_rows_by_key = {}
            local merged_rows = {}

            if not is_reputations_success then
                callback(false, nil, reputations_error)
                return
            end

            for _, reputation_row in ipairs(reputation_rows or {}) do
                reputation_rows_by_key[reputation_row.reputation_key] = reputation_row
            end

            for _, definition_row in ipairs(definition_rows or {}) do
                local existing_row = nil
                local value = 0
                local rank = nil

                if definition_row.is_active == true then
                    existing_row = reputation_rows_by_key[definition_row.key]
                    value = existing_row ~= nil and (normalize_integer(existing_row.value) or 0)
                        or clamp_value(definition_row.default_value, definition_row.min_value, definition_row.max_value)
                    rank = existing_row ~= nil and existing_row.rank or self:ComputeRank(value)

                    merged_rows[#merged_rows + 1] = {
                        character_id = normalized_character_id,
                        reputation_key = definition_row.key,
                        value = value,
                        rank = rank,
                        name = definition_row.name,
                        description = definition_row.description,
                        min_value = definition_row.min_value,
                        max_value = definition_row.max_value,
                        default_value = definition_row.default_value,
                        is_active = definition_row.is_active,
                        created_at = existing_row ~= nil and existing_row.created_at or definition_row.created_at,
                        updated_at = existing_row ~= nil and existing_row.updated_at or definition_row.updated_at,
                    }
                end
            end

            callback(true, merged_rows, nil)
        end)
    end)
end

function ReputationService:AddReputation(character_id, reputation_key, amount, reason, callback)
    local normalized_character_id = normalize_positive_integer(character_id)
    local normalized_reputation_key = normalize_reputation_key(reputation_key)
    local normalized_amount = normalize_integer(amount)
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

    if normalized_reputation_key == nil then
        callback(false, nil, "reputation-key-required")
        return true
    end

    if normalized_amount == nil or normalized_amount == 0 then
        callback(false, nil, "reputation-amount-required")
        return true
    end

    return self.repository:GetDefinition(normalized_reputation_key, function(is_definition_success, definition_row, definition_error)
        if not is_definition_success then
            Console.Log(
                "[gr_reputation][service] Reputation change failed character_id=%s reputation_key=%s reason=%s.",
                tostring(normalized_character_id),
                tostring(normalized_reputation_key),
                tostring(definition_error)
            )
            callback(false, nil, definition_error)
            return
        end

        if definition_row == nil or definition_row.is_active ~= true then
            Console.Log(
                "[gr_reputation][service] Reputation change failed character_id=%s reputation_key=%s reason=%s.",
                tostring(normalized_character_id),
                tostring(normalized_reputation_key),
                "reputation-not-found"
            )
            callback(false, nil, "reputation-not-found")
            return
        end

        self.repository:GetCharacterReputation(normalized_character_id, normalized_reputation_key, function(is_row_success, reputation_row, row_error)
            local current_value = 0
            local next_value = 0
            local next_rank = nil

            if not is_row_success then
                Console.Log(
                    "[gr_reputation][service] Reputation change failed character_id=%s reputation_key=%s reason=%s.",
                    tostring(normalized_character_id),
                    tostring(normalized_reputation_key),
                    tostring(row_error)
                )
                callback(false, nil, row_error)
                return
            end

            current_value = reputation_row ~= nil and (normalize_integer(reputation_row.value) or 0)
                or clamp_value(definition_row.default_value, definition_row.min_value, definition_row.max_value)
            next_value = clamp_value(current_value + normalized_amount, definition_row.min_value, definition_row.max_value)
            next_rank = self:ComputeRank(next_value)

            self.repository:UpsertCharacterReputation(
                normalized_character_id,
                normalized_reputation_key,
                next_value,
                next_rank,
                function(is_upsert_success, saved_row, upsert_error)
                    if not is_upsert_success then
                        Console.Log(
                            "[gr_reputation][service] Reputation change failed character_id=%s reputation_key=%s reason=%s.",
                            tostring(normalized_character_id),
                            tostring(normalized_reputation_key),
                            tostring(upsert_error)
                        )
                        callback(false, nil, upsert_error)
                        return
                    end

                    Console.Log(
                        "[gr_reputation][service] Reputation changed character_id=%s reputation_key=%s delta=%s value=%s rank=%s reason=%s.",
                        tostring(normalized_character_id),
                        tostring(normalized_reputation_key),
                        tostring(normalized_amount),
                        tostring(next_value),
                        tostring(next_rank),
                        tostring(normalized_reason)
                    )

                    callback(true, {
                        character_id = normalized_character_id,
                        reputation_key = normalized_reputation_key,
                        value = next_value,
                        rank = next_rank,
                        delta = normalized_amount,
                        row = saved_row,
                    }, nil)
                end
            )
        end)
    end)
end

function ReputationService:SetReputation(character_id, reputation_key, value, reason, callback)
    local normalized_character_id = normalize_positive_integer(character_id)
    local normalized_reputation_key = normalize_reputation_key(reputation_key)
    local normalized_value = normalize_integer(value)
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

    if normalized_reputation_key == nil then
        callback(false, nil, "reputation-key-required")
        return true
    end

    if normalized_value == nil then
        callback(false, nil, "reputation-value-required")
        return true
    end

    return self.repository:GetDefinition(normalized_reputation_key, function(is_definition_success, definition_row, definition_error)
        if not is_definition_success then
            callback(false, nil, definition_error)
            return
        end

        if definition_row == nil or definition_row.is_active ~= true then
            callback(false, nil, "reputation-not-found")
            return
        end

        local clamped_value = clamp_value(normalized_value, definition_row.min_value, definition_row.max_value)
        local next_rank = self:ComputeRank(clamped_value)

        self.repository:UpsertCharacterReputation(
            normalized_character_id,
            normalized_reputation_key,
            clamped_value,
            next_rank,
            function(is_upsert_success, saved_row, upsert_error)
                if not is_upsert_success then
                    callback(false, nil, upsert_error)
                    return
                end

                Console.Log(
                    "[gr_reputation][service] Reputation changed character_id=%s reputation_key=%s delta=%s value=%s rank=%s reason=%s.",
                    tostring(normalized_character_id),
                    tostring(normalized_reputation_key),
                    tostring(clamped_value),
                    tostring(clamped_value),
                    tostring(next_rank),
                    tostring(normalized_reason)
                )

                callback(true, {
                    character_id = normalized_character_id,
                    reputation_key = normalized_reputation_key,
                    value = clamped_value,
                    rank = next_rank,
                    delta = clamped_value,
                    row = saved_row,
                }, nil)
            end
        )
    end)
end

GRReputation.Server.ReputationServiceClass = ReputationService

return ReputationService

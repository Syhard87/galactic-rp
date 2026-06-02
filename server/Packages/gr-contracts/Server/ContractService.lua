GRContracts = GRContracts or {}
GRContracts.Server = GRContracts.Server or {}

local ContractService = {}
ContractService.__index = ContractService

local ALLOWED_CONTRACT_TYPES = {
    crafting = true,
    delivery = true,
    information = true,
    medical = true,
    protection = true,
    repair = true,
}

local CONTRACT_TYPE_TITLES = {
    crafting = "Crafting",
    delivery = "Delivery",
    information = "Information",
    medical = "Medical",
    protection = "Protection",
    repair = "Repair",
}

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

local function normalize_reward_money(value)
    if type(value) == "number" then
        if value < 0 or value > 100000 or value % 1 ~= 0 then
            return nil
        end

        return math.floor(value)
    end

    if type(value) == "string" and value:match("^%d+$") ~= nil then
        local parsed_value = tonumber(value)

        if parsed_value ~= nil and parsed_value >= 0 and parsed_value <= 100000 then
            return math.floor(parsed_value)
        end
    end

    return nil
end

local function normalize_contract_id(value)
    return normalize_positive_integer(value)
end

local function normalize_contract_type(contract_type)
    local normalized_contract_type = trim_string(contract_type)

    if normalized_contract_type == nil then
        return nil
    end

    normalized_contract_type = string.lower(normalized_contract_type)

    if ALLOWED_CONTRACT_TYPES[normalized_contract_type] ~= true then
        return nil
    end

    return normalized_contract_type
end

local function normalize_description(description)
    local normalized_description = trim_string(description)

    if normalized_description == nil then
        return nil
    end

    if #normalized_description > 500 then
        return nil
    end

    return normalized_description
end

local function build_contract_title(contract_type)
    return CONTRACT_TYPE_TITLES[contract_type] or contract_type
end

local function callback_repository_missing(callback)
    if type(callback) == "function" then
        callback(false, nil, "contracts-repository-missing")
    end

    return true
end

local function resolve_contract_role(contract_row, character_id)
    local normalized_character_id = normalize_positive_integer(character_id)
    local is_creator = false
    local is_assignee = false

    if normalized_character_id == nil or type(contract_row) ~= "table" then
        return "unknown"
    end

    is_creator = normalize_positive_integer(contract_row.creator_character_id) == normalized_character_id
    is_assignee = normalize_positive_integer(contract_row.assignee_character_id) == normalized_character_id

    if is_creator and is_assignee then
        return "creator+assignee"
    end

    if is_assignee then
        return "assignee"
    end

    if is_creator then
        return "creator"
    end

    return "unknown"
end

function ContractService.Create(repository)
    local self = setmetatable({}, ContractService)

    self.repository = repository

    return self
end

function ContractService:CreateContract(character_id, contract_type, reward_money, description, callback)
    local normalized_character_id = normalize_positive_integer(character_id)
    local normalized_contract_type = normalize_contract_type(contract_type)
    local normalized_reward_money = normalize_reward_money(reward_money)
    local normalized_description = normalize_description(description)

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

    if normalized_contract_type == nil then
        callback(false, nil, "contract-type-invalid")
        return true
    end

    if normalized_reward_money == nil then
        callback(false, nil, "reward-money-invalid")
        return true
    end

    if normalized_description == nil then
        callback(false, nil, "description-invalid")
        return true
    end

    return self.repository:CreateContract({
        creator_character_id = normalized_character_id,
        type = normalized_contract_type,
        title = build_contract_title(normalized_contract_type),
        description = normalized_description,
        reward_money = normalized_reward_money,
        deadline_at = nil,
    }, function(is_success, contract_row, error)
        if not is_success then
            callback(false, nil, error)
            return
        end

        Console.Log(
            "[gr_contracts][service] Contract created id=%s creator_character_id=%s type=%s reward_money=%s.",
            tostring(contract_row and contract_row.id),
            tostring(normalized_character_id),
            tostring(normalized_contract_type),
            tostring(normalized_reward_money)
        )

        callback(true, contract_row, nil)
    end)
end

function ContractService:ListOpenContracts(callback)
    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if self.repository == nil then
        return callback_repository_missing(callback)
    end

    return self.repository:ListOpenContracts(callback)
end

function ContractService:ListMyContracts(character_id, callback)
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

    return self.repository:ListContractsForCharacter(normalized_character_id, function(is_success, contract_rows, error)
        local results = {}

        if not is_success then
            callback(false, nil, error)
            return
        end

        for _, contract_row in ipairs(contract_rows or {}) do
            local enriched_row = {}

            for key, value in pairs(contract_row) do
                enriched_row[key] = value
            end

            enriched_row.role = resolve_contract_role(contract_row, normalized_character_id)
            results[#results + 1] = enriched_row
        end

        callback(true, results, nil)
    end)
end

function ContractService:AcceptContract(character_id, contract_id, callback)
    local normalized_character_id = normalize_positive_integer(character_id)
    local normalized_contract_id = normalize_contract_id(contract_id)

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

    if normalized_contract_id == nil then
        callback(false, nil, "contract-id-invalid")
        return true
    end

    return self.repository:GetContractById(normalized_contract_id, function(is_get_success, contract_row, get_error)
        if not is_get_success then
            callback(false, nil, get_error)
            return
        end

        if contract_row == nil then
            callback(false, nil, "contract-not-found")
            return
        end

        if contract_row.status ~= "open" then
            callback(false, nil, "contract-not-available")
            return
        end

        self.repository:AcceptContract(normalized_contract_id, normalized_character_id, function(is_accept_success, accepted_row, accept_error)
            if not is_accept_success then
                callback(false, nil, accept_error)
                return
            end

            if accepted_row == nil then
                callback(false, nil, "contract-not-available")
                return
            end

            Console.Log(
                "[gr_contracts][service] Contract accepted id=%s assignee_character_id=%s.",
                tostring(accepted_row.id),
                tostring(normalized_character_id)
            )

            callback(true, accepted_row, nil)
        end)
    end)
end

function ContractService:CompleteContract(character_id, contract_id, callback)
    local normalized_character_id = normalize_positive_integer(character_id)
    local normalized_contract_id = normalize_contract_id(contract_id)

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

    if normalized_contract_id == nil then
        callback(false, nil, "contract-id-invalid")
        return true
    end

    return self.repository:GetContractById(normalized_contract_id, function(is_get_success, contract_row, get_error)
        if not is_get_success then
            callback(false, nil, get_error)
            return
        end

        if contract_row == nil then
            callback(false, nil, "contract-not-found")
            return
        end

        if contract_row.status ~= "accepted"
            or normalize_positive_integer(contract_row.assignee_character_id) ~= normalized_character_id
        then
            callback(false, nil, "contract-complete-forbidden")
            return
        end

        self.repository:CompleteContract(normalized_contract_id, normalized_character_id, function(is_complete_success, completed_row, complete_error)
            if not is_complete_success then
                callback(false, nil, complete_error)
                return
            end

            if completed_row == nil then
                callback(false, nil, "contract-complete-forbidden")
                return
            end

            Console.Log(
                "[gr_contracts][service] Contract completed id=%s assignee_character_id=%s.",
                tostring(completed_row.id),
                tostring(normalized_character_id)
            )

            callback(true, completed_row, nil)
        end)
    end)
end

function ContractService:CancelContract(character_id, contract_id, callback)
    local normalized_character_id = normalize_positive_integer(character_id)
    local normalized_contract_id = normalize_contract_id(contract_id)

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

    if normalized_contract_id == nil then
        callback(false, nil, "contract-id-invalid")
        return true
    end

    return self.repository:GetContractById(normalized_contract_id, function(is_get_success, contract_row, get_error)
        if not is_get_success then
            callback(false, nil, get_error)
            return
        end

        if contract_row == nil then
            callback(false, nil, "contract-not-found")
            return
        end

        if contract_row.status ~= "open"
            or normalize_positive_integer(contract_row.creator_character_id) ~= normalized_character_id
        then
            callback(false, nil, "contract-cancel-forbidden")
            return
        end

        self.repository:CancelContract(normalized_contract_id, normalized_character_id, function(is_cancel_success, cancelled_row, cancel_error)
            if not is_cancel_success then
                callback(false, nil, cancel_error)
                return
            end

            if cancelled_row == nil then
                callback(false, nil, "contract-cancel-forbidden")
                return
            end

            Console.Log(
                "[gr_contracts][service] Contract cancelled id=%s creator_character_id=%s.",
                tostring(cancelled_row.id),
                tostring(normalized_character_id)
            )

            callback(true, cancelled_row, nil)
        end)
    end)
end

GRContracts.Server.ContractServiceClass = ContractService

return ContractService

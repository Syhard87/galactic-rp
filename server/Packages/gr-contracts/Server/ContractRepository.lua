GRContracts = GRContracts or {}
GRContracts.Server = GRContracts.Server or {}

local ContractRepository = {}
ContractRepository.__index = ContractRepository

local CONTRACT_SELECT_COLUMNS = [[
        id,
        creator_character_id,
        assignee_character_id,
        type,
        title,
        description,
        reward_money,
        required_item_key,
        required_item_quantity,
        consume_required_items,
        delivery_location_key,
        requires_delivery_location,
        status,
        payment_status,
        created_at,
        accepted_at,
        completed_at,
        cancelled_at,
        paid_at,
        deadline_at
]]

local SELECT_DELIVERY_LOCATIONS_QUERY = [[
    SELECT
        id,
        key,
        name,
        description,
        location_type,
        position_x,
        position_y,
        position_z,
        radius,
        is_active,
        created_at,
        updated_at
    FROM contract_delivery_locations
    ORDER BY key ASC
]]

local SELECT_DELIVERY_LOCATION_BY_KEY_QUERY = [[
    SELECT
        id,
        key,
        name,
        description,
        location_type,
        position_x,
        position_y,
        position_z,
        radius,
        is_active,
        created_at,
        updated_at
    FROM contract_delivery_locations
    WHERE key = :0
    LIMIT 1
]]

local INSERT_CONTRACT_QUERY = [[
    INSERT INTO contracts (
        creator_character_id,
        type,
        title,
        description,
        reward_money,
        required_item_key,
        required_item_quantity,
        consume_required_items,
        delivery_location_key,
        requires_delivery_location,
        status,
        deadline_at
    )
    VALUES (
        :0,
        :1,
        :2,
        :3,
        :4,
        :5,
        :6,
        :7,
        :8,
        :9,
        'open',
        :10
    )
    RETURNING
]] .. CONTRACT_SELECT_COLUMNS .. [[
]]

local SELECT_OPEN_CONTRACTS_QUERY = [[
    SELECT
]] .. CONTRACT_SELECT_COLUMNS .. [[
    FROM contracts
    WHERE status = 'open'
    ORDER BY id ASC
]]

local SELECT_CONTRACTS_FOR_CHARACTER_QUERY = [[
    SELECT
]] .. CONTRACT_SELECT_COLUMNS .. [[
    FROM contracts
    WHERE creator_character_id = :0 OR assignee_character_id = :1
    ORDER BY id ASC
]]

local SELECT_CONTRACT_BY_ID_QUERY = [[
    SELECT
]] .. CONTRACT_SELECT_COLUMNS .. [[
    FROM contracts
    WHERE id = :0
    LIMIT 1
]]

local ACCEPT_CONTRACT_QUERY = [[
    UPDATE contracts
    SET
        assignee_character_id = :1,
        status = 'accepted',
        accepted_at = NOW()
    WHERE id = :0 AND status = 'open'
    RETURNING
]] .. CONTRACT_SELECT_COLUMNS .. [[
]]

local COMPLETE_CONTRACT_QUERY = [[
    UPDATE contracts
    SET
        status = 'completed',
        completed_at = NOW()
    WHERE id = :0 AND assignee_character_id = :1 AND status = 'accepted'
    RETURNING
]] .. CONTRACT_SELECT_COLUMNS .. [[
]]

local CANCEL_CONTRACT_QUERY = [[
    UPDATE contracts
    SET
        status = 'cancelled',
        cancelled_at = NOW()
    WHERE id = :0 AND creator_character_id = :1 AND status = 'open'
    RETURNING
]] .. CONTRACT_SELECT_COLUMNS .. [[
]]

local UPDATE_CONTRACT_PAYMENT_STATUS_QUERY = [[
    UPDATE contracts
    SET
        payment_status = :1,
        paid_at = CASE
            WHEN :1 = 'paid' THEN NOW()
            ELSE paid_at
        END
    WHERE id = :0
    RETURNING
]] .. CONTRACT_SELECT_COLUMNS .. [[
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

local function normalize_number(value, fallback)
    if type(value) == "number" then
        if value ~= value or value == math.huge or value == -math.huge then
            return fallback
        end

        return value
    end

    if type(value) == "string" then
        local parsed_value = tonumber(value)

        if parsed_value ~= nil and parsed_value == parsed_value and parsed_value ~= math.huge and parsed_value ~= -math.huge then
            return parsed_value
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

local function normalize_item_key(item_key)
    local normalized_item_key = trim_string(item_key)

    if normalized_item_key == nil then
        return nil
    end

    if normalized_item_key:match("^[a-z0-9_]+$") == nil then
        return nil
    end

    return string.lower(normalized_item_key)
end

local function normalize_location_key(location_key)
    local normalized_location_key = trim_string(location_key)

    if normalized_location_key == nil then
        return nil
    end

    if normalized_location_key:match("^[a-z0-9_]+$") == nil then
        return nil
    end

    return string.lower(normalized_location_key)
end

local function normalize_contract_type(contract_type)
    local normalized_contract_type = trim_string(contract_type)

    if normalized_contract_type == nil then
        return nil
    end

    normalized_contract_type = string.lower(normalized_contract_type)

    if normalized_contract_type:match("^[a-z_]+$") == nil then
        return nil
    end

    return normalized_contract_type
end

local function normalize_contract_status(status)
    local normalized_status = trim_string(status)

    if normalized_status == nil then
        return "open"
    end

    normalized_status = string.lower(normalized_status)

    if normalized_status ~= "open"
        and normalized_status ~= "accepted"
        and normalized_status ~= "completed"
        and normalized_status ~= "cancelled"
    then
        return "open"
    end

    return normalized_status
end

local function normalize_payment_status(payment_status)
    local normalized_payment_status = trim_string(payment_status)

    if normalized_payment_status == nil then
        return "pending"
    end

    normalized_payment_status = string.lower(normalized_payment_status)

    if normalized_payment_status ~= "pending"
        and normalized_payment_status ~= "paid"
        and normalized_payment_status ~= "unavailable"
        and normalized_payment_status ~= "failed"
    then
        return "pending"
    end

    return normalized_payment_status
end

local function normalize_contract_row(row)
    local contract_id = nil
    local creator_character_id = nil
    local contract_type = nil

    if type(row) ~= "table" then
        return nil
    end

    contract_id = normalize_positive_integer(row.id)
    creator_character_id = normalize_positive_integer(row.creator_character_id)
    contract_type = normalize_contract_type(row.type)

    if contract_id == nil or creator_character_id == nil or contract_type == nil then
        return nil
    end

    return {
        id = contract_id,
        creator_character_id = creator_character_id,
        assignee_character_id = normalize_positive_integer(row.assignee_character_id),
        type = contract_type,
        title = trim_string(row.title) or contract_type,
        description = trim_string(row.description) or "",
        reward_money = normalize_non_negative_integer(row.reward_money, 0),
        required_item_key = normalize_item_key(row.required_item_key),
        required_item_quantity = normalize_non_negative_integer(row.required_item_quantity, 0),
        consume_required_items = normalize_boolean(row.consume_required_items, true),
        delivery_location_key = normalize_location_key(row.delivery_location_key),
        requires_delivery_location = normalize_boolean(row.requires_delivery_location, false),
        status = normalize_contract_status(row.status),
        payment_status = normalize_payment_status(row.payment_status),
        created_at = row.created_at,
        accepted_at = row.accepted_at,
        completed_at = row.completed_at,
        cancelled_at = row.cancelled_at,
        paid_at = row.paid_at,
        deadline_at = row.deadline_at,
    }
end

local function normalize_delivery_location_row(row)
    local location_id = nil
    local location_key = nil

    if type(row) ~= "table" then
        return nil
    end

    location_id = normalize_positive_integer(row.id)
    location_key = normalize_location_key(row.key)

    if location_id == nil or location_key == nil then
        return nil
    end

    return {
        id = location_id,
        key = location_key,
        name = trim_string(row.name) or location_key,
        description = trim_string(row.description) or "",
        location_type = trim_string(row.location_type) or "delivery",
        position_x = normalize_number(row.position_x, nil),
        position_y = normalize_number(row.position_y, nil),
        position_z = normalize_number(row.position_z, nil),
        radius = normalize_number(row.radius, 500.0) or 500.0,
        is_active = normalize_boolean(row.is_active, true),
        created_at = row.created_at,
        updated_at = row.updated_at,
    }
end

local function normalize_delivery_location_rows(rows)
    local normalized_rows = {}

    for _, row in ipairs(rows or {}) do
        local normalized_row = normalize_delivery_location_row(row)

        if normalized_row ~= nil then
            normalized_rows[#normalized_rows + 1] = normalized_row
        end
    end

    return normalized_rows
end

local function normalize_rows(rows)
    local normalized_rows = {}

    for _, row in ipairs(rows or {}) do
        local normalized_row = normalize_contract_row(row)

        if normalized_row ~= nil then
            normalized_rows[#normalized_rows + 1] = normalized_row
        end
    end

    return normalized_rows
end

function ContractRepository.Create(database_service)
    local self = setmetatable({}, ContractRepository)

    self.database_service = database_service

    return self
end

function ContractRepository:Connect(callback, reason)
    local is_connected = false
    local database_or_error = nil

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if self.database_service == nil then
        Console.Log(
            "[gr_contracts][repository] Database service unavailable during %s.",
            tostring(reason or "contracts-call")
        )
        callback(false, nil, "database-service-missing")
        return true
    end

    is_connected, database_or_error = self.database_service:Connect()

    if not is_connected then
        Console.Log(
            "[gr_contracts][repository] Database connection failed during %s with error=%s.",
            tostring(reason or "contracts-call"),
            tostring(database_or_error)
        )
        callback(false, nil, database_or_error)
        return true
    end

    callback(true, database_or_error, nil)
    return true
end

function ContractRepository:CreateContract(contract, callback)
    local normalized_creator_character_id = normalize_positive_integer(contract and contract.creator_character_id)
    local normalized_contract_type = normalize_contract_type(contract and contract.type)
    local normalized_title = trim_string(contract and contract.title)
    local normalized_description = trim_string(contract and contract.description)
    local normalized_reward_money = normalize_non_negative_integer(contract and contract.reward_money, nil)
    local normalized_required_item_key = normalize_item_key(contract and contract.required_item_key)
    local normalized_required_item_quantity = normalize_non_negative_integer(contract and contract.required_item_quantity, 0)
    local normalized_consume_required_items = normalize_boolean(contract and contract.consume_required_items, true)
    local normalized_delivery_location_key = normalize_location_key(contract and contract.delivery_location_key)
    local normalized_requires_delivery_location = normalize_boolean(contract and contract.requires_delivery_location, false)
    local normalized_deadline_at = contract ~= nil and contract.deadline_at or nil

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if normalized_creator_character_id == nil then
        callback(false, nil, "creator-character-id-required")
        return true
    end

    if normalized_contract_type == nil then
        callback(false, nil, "contract-type-required")
        return true
    end

    if normalized_title == nil then
        callback(false, nil, "contract-title-required")
        return true
    end

    if normalized_description == nil then
        callback(false, nil, "contract-description-required")
        return true
    end

    if normalized_reward_money == nil then
        callback(false, nil, "reward-money-required")
        return true
    end

    if normalized_required_item_key == nil and normalized_required_item_quantity > 0 then
        callback(false, nil, "required-item-key-invalid")
        return true
    end

    if normalized_requires_delivery_location and normalized_delivery_location_key == nil then
        callback(false, nil, "delivery-location-key-invalid")
        return true
    end

    return self:Connect(function(is_connected, database_or_error, error)
        if not is_connected then
            callback(false, nil, error)
            return
        end

        database_or_error:SelectAsync(
            INSERT_CONTRACT_QUERY,
            function(rows, insert_error)
                local contract_rows = nil

                if insert_error ~= nil then
                    callback(false, nil, insert_error)
                    return
                end

                contract_rows = normalize_rows(rows)
                callback(true, contract_rows[1], nil)
            end,
            normalized_creator_character_id,
            normalized_contract_type,
            normalized_title,
            normalized_description,
            normalized_reward_money,
            normalized_required_item_key,
            normalized_required_item_quantity,
            normalized_consume_required_items,
            normalized_delivery_location_key,
            normalized_requires_delivery_location,
            normalized_deadline_at
        )
    end, "contracts-create")
end

function ContractRepository:ListDeliveryLocations(callback)
    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    return self:Connect(function(is_connected, database_or_error, error)
        if not is_connected then
            callback(false, nil, error)
            return
        end

        database_or_error:SelectAsync(SELECT_DELIVERY_LOCATIONS_QUERY, function(rows, select_error)
            if select_error ~= nil then
                callback(false, nil, select_error)
                return
            end

            callback(true, normalize_delivery_location_rows(rows), nil)
        end)
    end, "contracts-list-delivery-locations")
end

function ContractRepository:GetDeliveryLocation(location_key, callback)
    local normalized_location_key = normalize_location_key(location_key)

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if normalized_location_key == nil then
        callback(false, nil, "delivery-location-key-required")
        return true
    end

    return self:Connect(function(is_connected, database_or_error, error)
        if not is_connected then
            callback(false, nil, error)
            return
        end

        database_or_error:SelectAsync(SELECT_DELIVERY_LOCATION_BY_KEY_QUERY, function(rows, select_error)
            local delivery_locations = nil

            if select_error ~= nil then
                callback(false, nil, select_error)
                return
            end

            delivery_locations = normalize_delivery_location_rows(rows)
            callback(true, delivery_locations[1], nil)
        end, normalized_location_key)
    end, "contracts-get-delivery-location")
end

function ContractRepository:ListOpenContracts(callback)
    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    return self:Connect(function(is_connected, database_or_error, error)
        if not is_connected then
            callback(false, nil, error)
            return
        end

        database_or_error:SelectAsync(SELECT_OPEN_CONTRACTS_QUERY, function(rows, select_error)
            if select_error ~= nil then
                callback(false, nil, select_error)
                return
            end

            callback(true, normalize_rows(rows), nil)
        end)
    end, "contracts-list-open")
end

function ContractRepository:ListContractsForCharacter(character_id, callback)
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

        database_or_error:SelectAsync(SELECT_CONTRACTS_FOR_CHARACTER_QUERY, function(rows, select_error)
            if select_error ~= nil then
                callback(false, nil, select_error)
                return
            end

            callback(true, normalize_rows(rows), nil)
        end, normalized_character_id, normalized_character_id)
    end, "contracts-list-character")
end

function ContractRepository:GetContractById(contract_id, callback)
    local normalized_contract_id = normalize_positive_integer(contract_id)

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if normalized_contract_id == nil then
        callback(false, nil, "contract-id-required")
        return true
    end

    return self:Connect(function(is_connected, database_or_error, error)
        if not is_connected then
            callback(false, nil, error)
            return
        end

        database_or_error:SelectAsync(SELECT_CONTRACT_BY_ID_QUERY, function(rows, select_error)
            local contract_rows = nil

            if select_error ~= nil then
                callback(false, nil, select_error)
                return
            end

            contract_rows = normalize_rows(rows)
            callback(true, contract_rows[1], nil)
        end, normalized_contract_id)
    end, "contracts-get-by-id")
end

function ContractRepository:AcceptContract(contract_id, assignee_character_id, callback)
    local normalized_contract_id = normalize_positive_integer(contract_id)
    local normalized_assignee_character_id = normalize_positive_integer(assignee_character_id)

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if normalized_contract_id == nil then
        callback(false, nil, "contract-id-required")
        return true
    end

    if normalized_assignee_character_id == nil then
        callback(false, nil, "assignee-character-id-required")
        return true
    end

    return self:Connect(function(is_connected, database_or_error, error)
        if not is_connected then
            callback(false, nil, error)
            return
        end

        database_or_error:SelectAsync(ACCEPT_CONTRACT_QUERY, function(rows, update_error)
            local contract_rows = nil

            if update_error ~= nil then
                callback(false, nil, update_error)
                return
            end

            contract_rows = normalize_rows(rows)
            callback(true, contract_rows[1], nil)
        end, normalized_contract_id, normalized_assignee_character_id)
    end, "contracts-accept")
end

function ContractRepository:CompleteContract(contract_id, character_id, callback)
    local normalized_contract_id = normalize_positive_integer(contract_id)
    local normalized_character_id = normalize_positive_integer(character_id)

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if normalized_contract_id == nil then
        callback(false, nil, "contract-id-required")
        return true
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

        database_or_error:SelectAsync(COMPLETE_CONTRACT_QUERY, function(rows, update_error)
            local contract_rows = nil

            if update_error ~= nil then
                callback(false, nil, update_error)
                return
            end

            contract_rows = normalize_rows(rows)
            callback(true, contract_rows[1], nil)
        end, normalized_contract_id, normalized_character_id)
    end, "contracts-complete")
end

function ContractRepository:CancelContract(contract_id, character_id, callback)
    local normalized_contract_id = normalize_positive_integer(contract_id)
    local normalized_character_id = normalize_positive_integer(character_id)

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if normalized_contract_id == nil then
        callback(false, nil, "contract-id-required")
        return true
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

        database_or_error:SelectAsync(CANCEL_CONTRACT_QUERY, function(rows, update_error)
            local contract_rows = nil

            if update_error ~= nil then
                callback(false, nil, update_error)
                return
            end

            contract_rows = normalize_rows(rows)
            callback(true, contract_rows[1], nil)
        end, normalized_contract_id, normalized_character_id)
    end, "contracts-cancel")
end

function ContractRepository:MarkContractPayment(contract_id, payment_status, callback)
    local normalized_contract_id = normalize_positive_integer(contract_id)
    local normalized_payment_status = normalize_payment_status(payment_status)

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if normalized_contract_id == nil then
        callback(false, nil, "contract-id-required")
        return true
    end

    return self:Connect(function(is_connected, database_or_error, error)
        if not is_connected then
            callback(false, nil, error)
            return
        end

        database_or_error:SelectAsync(UPDATE_CONTRACT_PAYMENT_STATUS_QUERY, function(rows, update_error)
            local contract_rows = nil

            if update_error ~= nil then
                callback(false, nil, update_error)
                return
            end

            contract_rows = normalize_rows(rows)
            callback(true, contract_rows[1], nil)
        end, normalized_contract_id, normalized_payment_status)
    end, "contracts-mark-payment")
end

GRContracts.Server.ContractRepositoryClass = ContractRepository

return ContractRepository

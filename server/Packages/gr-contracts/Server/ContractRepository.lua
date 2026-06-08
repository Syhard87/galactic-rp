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
        pickup_location_key,
        requires_pickup_location,
        pickup_status,
        picked_up_at,
        delivery_location_key,
        requires_delivery_location,
        deadline_seconds,
        expires_at,
        expired_at,
        source_route_key,
        job_source,
        status,
        payment_status,
        created_at,
        accepted_at,
        completed_at,
        cancelled_at,
        cancelled_by_character_id,
        cancel_reason,
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

local SELECT_ROUTE_TEMPLATES_QUERY = [[
    SELECT
        id,
        key,
        name,
        description,
        item_key,
        item_quantity,
        reward_money,
        pickup_location_key,
        delivery_location_key,
        deadline_seconds,
        is_active,
        created_at,
        updated_at
    FROM contract_route_templates
    ORDER BY key ASC
]]

local SELECT_ROUTE_TEMPLATE_BY_KEY_QUERY = [[
    SELECT
        id,
        key,
        name,
        description,
        item_key,
        item_quantity,
        reward_money,
        pickup_location_key,
        delivery_location_key,
        deadline_seconds,
        is_active,
        created_at,
        updated_at
    FROM contract_route_templates
    WHERE key = :0
    LIMIT 1
]]

local UPDATE_DELIVERY_LOCATION_POSITION_QUERY = [[
    UPDATE contract_delivery_locations
    SET
        position_x = :1,
        position_y = :2,
        position_z = :3,
        radius = :4,
        updated_at = NOW()
    WHERE key = :0 AND is_active = true
    RETURNING
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
        pickup_location_key,
        requires_pickup_location,
        pickup_status,
        delivery_location_key,
        requires_delivery_location,
        deadline_seconds,
        expires_at,
        source_route_key,
        job_source,
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
        :10,
        :11,
        :12,
        :13,
        CASE
            WHEN :13 IS NULL THEN NULL
            ELSE NOW() + (:13 * INTERVAL '1 second')
        END,
        :14,
        :15,
        'open',
        :16
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

local MARK_CONTRACT_PICKED_UP_QUERY = [[
    UPDATE contracts
    SET
        pickup_status = 'picked_up',
        picked_up_at = NOW()
    WHERE id = :0 AND status = 'accepted' AND pickup_status = 'pending'
    RETURNING
]] .. CONTRACT_SELECT_COLUMNS .. [[
]]

local CANCEL_CONTRACT_QUERY = [[
    UPDATE contracts
    SET
        status = 'cancelled',
        cancelled_at = NOW(),
        cancelled_by_character_id = :2,
        cancel_reason = :3
    WHERE id = :0 AND creator_character_id = :1 AND status = 'open'
    RETURNING
]] .. CONTRACT_SELECT_COLUMNS .. [[
]]

local MARK_CONTRACT_ABANDONED_QUERY = [[
    UPDATE contracts
    SET
        status = 'cancelled',
        cancelled_at = NOW(),
        cancelled_by_character_id = :1,
        cancel_reason = :2
    WHERE id = :0
      AND assignee_character_id = :1
      AND status = 'accepted'
      AND COALESCE(payment_status, 'pending') <> 'paid'
    RETURNING
]] .. CONTRACT_SELECT_COLUMNS .. [[
]]

local MARK_CONTRACT_CANCELLED_QUERY = [[
    UPDATE contracts
    SET
        status = 'cancelled',
        cancelled_at = NOW(),
        cancelled_by_character_id = :1,
        cancel_reason = :2
    WHERE id = :0
      AND status <> 'completed'
      AND status <> 'cancelled'
      AND COALESCE(payment_status, 'pending') <> 'paid'
    RETURNING
]] .. CONTRACT_SELECT_COLUMNS .. [[
]]

local MARK_CONTRACT_EXPIRED_QUERY = [[
    UPDATE contracts
    SET
        status = 'expired',
        expired_at = NOW()
    WHERE id = :0
      AND status IN ('open', 'accepted')
      AND expires_at IS NOT NULL
      AND expires_at < NOW()
      AND COALESCE(payment_status, 'pending') <> 'paid'
    RETURNING
]] .. CONTRACT_SELECT_COLUMNS .. [[
]]

local MARK_EXPIRED_CONTRACTS_QUERY = [[
    UPDATE contracts
    SET
        status = 'expired',
        expired_at = NOW()
    WHERE status IN ('open', 'accepted')
      AND expires_at IS NOT NULL
      AND expires_at < NOW()
      AND COALESCE(payment_status, 'pending') <> 'paid'
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

local function normalize_route_key(route_key)
    local normalized_route_key = trim_string(route_key)

    if normalized_route_key == nil then
        return nil
    end

    if normalized_route_key:match("^[a-z0-9_]+$") == nil then
        return nil
    end

    return string.lower(normalized_route_key)
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
        and normalized_status ~= "expired"
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

local function normalize_pickup_status(pickup_status)
    local normalized_pickup_status = trim_string(pickup_status)

    if normalized_pickup_status == nil then
        return "none"
    end

    normalized_pickup_status = string.lower(normalized_pickup_status)

    if normalized_pickup_status ~= "none"
        and normalized_pickup_status ~= "pending"
        and normalized_pickup_status ~= "picked_up"
    then
        return "none"
    end

    return normalized_pickup_status
end

local function normalize_job_source(job_source)
    local normalized_job_source = trim_string(job_source)

    if normalized_job_source == nil then
        return nil
    end

    normalized_job_source = string.lower(normalized_job_source)

    if normalized_job_source ~= "manual"
        and normalized_job_source ~= "route_template"
        and normalized_job_source ~= "job_board"
    then
        return nil
    end

    return normalized_job_source
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
        pickup_location_key = normalize_location_key(row.pickup_location_key),
        requires_pickup_location = normalize_boolean(row.requires_pickup_location, false),
        pickup_status = normalize_pickup_status(row.pickup_status),
        picked_up_at = row.picked_up_at,
        delivery_location_key = normalize_location_key(row.delivery_location_key),
        requires_delivery_location = normalize_boolean(row.requires_delivery_location, false),
        deadline_seconds = normalize_positive_integer(row.deadline_seconds),
        expires_at = row.expires_at,
        expired_at = row.expired_at,
        source_route_key = normalize_route_key(row.source_route_key),
        job_source = normalize_job_source(row.job_source),
        status = normalize_contract_status(row.status),
        payment_status = normalize_payment_status(row.payment_status),
        created_at = row.created_at,
        accepted_at = row.accepted_at,
        completed_at = row.completed_at,
        cancelled_at = row.cancelled_at,
        cancelled_by_character_id = normalize_positive_integer(row.cancelled_by_character_id),
        cancel_reason = trim_string(row.cancel_reason),
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

local function normalize_route_template_row(row)
    local route_id = nil
    local route_key = nil

    if type(row) ~= "table" then
        return nil
    end

    route_id = normalize_positive_integer(row.id)
    route_key = normalize_route_key(row.key)

    if route_id == nil or route_key == nil then
        return nil
    end

    return {
        id = route_id,
        key = route_key,
        name = trim_string(row.name) or route_key,
        description = trim_string(row.description) or "",
        item_key = normalize_item_key(row.item_key),
        item_quantity = normalize_positive_integer(row.item_quantity),
        reward_money = normalize_non_negative_integer(row.reward_money, 0),
        pickup_location_key = normalize_location_key(row.pickup_location_key),
        delivery_location_key = normalize_location_key(row.delivery_location_key),
        deadline_seconds = normalize_positive_integer(row.deadline_seconds),
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

local function normalize_route_template_rows(rows)
    local normalized_rows = {}

    for _, row in ipairs(rows or {}) do
        local normalized_row = normalize_route_template_row(row)

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
    local normalized_pickup_location_key = normalize_location_key(contract and contract.pickup_location_key)
    local normalized_requires_pickup_location = normalize_boolean(contract and contract.requires_pickup_location, false)
    local normalized_pickup_status = normalize_pickup_status(contract and contract.pickup_status)
    local normalized_delivery_location_key = normalize_location_key(contract and contract.delivery_location_key)
    local normalized_requires_delivery_location = normalize_boolean(contract and contract.requires_delivery_location, false)
    local normalized_deadline_seconds = normalize_positive_integer(contract and contract.deadline_seconds)
    local normalized_source_route_key = normalize_route_key(contract and contract.source_route_key)
    local normalized_job_source = normalize_job_source(contract and contract.job_source)
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

    if normalized_requires_pickup_location and normalized_pickup_location_key == nil then
        callback(false, nil, "pickup-location-key-invalid")
        return true
    end

    if normalized_requires_delivery_location and normalized_delivery_location_key == nil then
        callback(false, nil, "delivery-location-key-invalid")
        return true
    end

    if normalized_source_route_key == nil and (normalized_job_source == "route_template" or normalized_job_source == "job_board") then
        callback(false, nil, "source-route-key-invalid")
        return true
    end

    if contract ~= nil and contract.deadline_seconds ~= nil and normalized_deadline_seconds == nil then
        callback(false, nil, "deadline-seconds-invalid")
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
            normalized_pickup_location_key,
            normalized_requires_pickup_location,
            normalized_pickup_status,
            normalized_delivery_location_key,
            normalized_requires_delivery_location,
            normalized_deadline_seconds,
            normalized_source_route_key,
            normalized_job_source,
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

function ContractRepository:ListRouteTemplates(callback)
    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    return self:Connect(function(is_connected, database_or_error, error)
        if not is_connected then
            callback(false, nil, error)
            return
        end

        database_or_error:SelectAsync(SELECT_ROUTE_TEMPLATES_QUERY, function(rows, select_error)
            if select_error ~= nil then
                callback(false, nil, select_error)
                return
            end

            callback(true, normalize_route_template_rows(rows), nil)
        end)
    end, "contracts-list-route-templates")
end

function ContractRepository:GetRouteTemplate(route_key, callback)
    local normalized_route_key = normalize_route_key(route_key)

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if normalized_route_key == nil then
        callback(false, nil, "route-key-required")
        return true
    end

    return self:Connect(function(is_connected, database_or_error, error)
        if not is_connected then
            callback(false, nil, error)
            return
        end

        database_or_error:SelectAsync(SELECT_ROUTE_TEMPLATE_BY_KEY_QUERY, function(rows, select_error)
            local route_templates = nil

            if select_error ~= nil then
                callback(false, nil, select_error)
                return
            end

            route_templates = normalize_route_template_rows(rows)
            callback(true, route_templates[1], nil)
        end, normalized_route_key)
    end, "contracts-get-route-template")
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

function ContractRepository:UpdateDeliveryLocationPosition(location_key, position_x, position_y, position_z, radius, callback)
    local normalized_location_key = normalize_location_key(location_key)
    local normalized_position_x = normalize_number(position_x, nil)
    local normalized_position_y = normalize_number(position_y, nil)
    local normalized_position_z = normalize_number(position_z, nil)
    local normalized_radius = normalize_number(radius, nil)

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if normalized_location_key == nil then
        callback(false, nil, "delivery-location-key-required")
        return true
    end

    if normalized_position_x == nil or normalized_position_y == nil or normalized_position_z == nil then
        callback(false, nil, "delivery-location-position-required")
        return true
    end

    if normalized_radius == nil or normalized_radius <= 0 then
        callback(false, nil, "delivery-location-radius-invalid")
        return true
    end

    return self:Connect(function(is_connected, database_or_error, error)
        if not is_connected then
            callback(false, nil, error)
            return
        end

        database_or_error:SelectAsync(UPDATE_DELIVERY_LOCATION_POSITION_QUERY, function(rows, update_error)
            local delivery_locations = nil

            if update_error ~= nil then
                callback(false, nil, update_error)
                return
            end

            delivery_locations = normalize_delivery_location_rows(rows)
            callback(true, delivery_locations[1], nil)
        end, normalized_location_key, normalized_position_x, normalized_position_y, normalized_position_z, normalized_radius)
    end, "contracts-update-delivery-location-position")
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

function ContractRepository:MarkContractPickedUp(contract_id, callback)
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

        database_or_error:SelectAsync(MARK_CONTRACT_PICKED_UP_QUERY, function(rows, update_error)
            local contract_rows = nil

            if update_error ~= nil then
                callback(false, nil, update_error)
                return
            end

            contract_rows = normalize_rows(rows)
            callback(true, contract_rows[1], nil)
        end, normalized_contract_id)
    end, "contracts-mark-picked-up")
end

function ContractRepository:CancelContract(contract_id, character_id, reason, callback)
    local normalized_contract_id = normalize_positive_integer(contract_id)
    local normalized_character_id = normalize_positive_integer(character_id)
    local normalized_reason = trim_string(reason)

    if type(reason) == "function" and callback == nil then
        callback = reason
        normalized_reason = nil
    end

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
        end, normalized_contract_id, normalized_character_id, normalized_character_id, normalized_reason)
    end, "contracts-cancel")
end

function ContractRepository:MarkContractAbandoned(contract_id, character_id, reason, callback)
    local normalized_contract_id = normalize_positive_integer(contract_id)
    local normalized_character_id = normalize_positive_integer(character_id)
    local normalized_reason = trim_string(reason)

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

        database_or_error:SelectAsync(MARK_CONTRACT_ABANDONED_QUERY, function(rows, update_error)
            local contract_rows = nil

            if update_error ~= nil then
                callback(false, nil, update_error)
                return
            end

            contract_rows = normalize_rows(rows)
            callback(true, contract_rows[1], nil)
        end, normalized_contract_id, normalized_character_id, normalized_reason)
    end, "contracts-abandon")
end

function ContractRepository:MarkContractCancelled(contract_id, character_id, reason, callback)
    local normalized_contract_id = normalize_positive_integer(contract_id)
    local normalized_character_id = normalize_positive_integer(character_id)
    local normalized_reason = trim_string(reason)

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

        database_or_error:SelectAsync(MARK_CONTRACT_CANCELLED_QUERY, function(rows, update_error)
            local contract_rows = nil

            if update_error ~= nil then
                callback(false, nil, update_error)
                return
            end

            contract_rows = normalize_rows(rows)
            callback(true, contract_rows[1], nil)
        end, normalized_contract_id, normalized_character_id, normalized_reason)
    end, "contracts-mark-cancelled")
end

function ContractRepository:MarkContractExpired(contract_id, callback)
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

        database_or_error:SelectAsync(MARK_CONTRACT_EXPIRED_QUERY, function(rows, update_error)
            local contract_rows = nil

            if update_error ~= nil then
                callback(false, nil, update_error)
                return
            end

            contract_rows = normalize_rows(rows)
            callback(true, contract_rows[1], nil)
        end, normalized_contract_id)
    end, "contracts-mark-expired")
end

function ContractRepository:MarkExpiredContracts(callback)
    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    return self:Connect(function(is_connected, database_or_error, error)
        if not is_connected then
            callback(false, nil, nil, error)
            return
        end

        database_or_error:SelectAsync(MARK_EXPIRED_CONTRACTS_QUERY, function(rows, update_error)
            local contract_rows = nil

            if update_error ~= nil then
                callback(false, nil, nil, update_error)
                return
            end

            contract_rows = normalize_rows(rows)
            callback(true, #contract_rows, contract_rows, nil)
        end)
    end, "contracts-mark-expired-batch")
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

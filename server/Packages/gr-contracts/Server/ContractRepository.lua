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
        reward_skill_key,
        reward_skill_xp,
        reward_reputation_key,
        reward_reputation_delta,
        rewards_status,
        rewards_granted_at,
        rewards_error,
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
        cargo_cleanup_status,
        cargo_cleaned_at,
        cargo_cleanup_error,
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

local CONTRACT_REWARD_GRANT_SELECT_COLUMNS = [[
        id,
        contract_id,
        character_id,
        reward_type,
        reward_key,
        amount,
        status,
        error_message,
        created_at,
        updated_at,
        applied_at
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

local INSERT_CONTRACT_LOCATION_QUERY = [[
    INSERT INTO contract_delivery_locations (
        key,
        name,
        description,
        location_type,
        position_x,
        position_y,
        position_z,
        radius,
        is_active
    )
    VALUES (
        :0,
        :1,
        :2,
        'delivery',
        NULL,
        NULL,
        NULL,
        :3,
        true
    )
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

local UPDATE_CONTRACT_LOCATION_ACTIVE_QUERY = [[
    UPDATE contract_delivery_locations
    SET
        is_active = :1,
        updated_at = NOW()
    WHERE key = :0
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

local UPDATE_CONTRACT_LOCATION_RADIUS_QUERY = [[
    UPDATE contract_delivery_locations
    SET
        radius = :1,
        updated_at = NOW()
    WHERE key = :0
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

local UPDATE_CONTRACT_LOCATION_NAME_QUERY = [[
    UPDATE contract_delivery_locations
    SET
        name = :1,
        updated_at = NOW()
    WHERE key = :0
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

local SELECT_ROUTE_TEMPLATES_QUERY = [[
    SELECT
        id,
        key,
        name,
        description,
        item_key,
        item_quantity,
        reward_money,
        reward_skill_key,
        reward_skill_xp,
        reward_reputation_key,
        reward_reputation_delta,
        required_skill_key,
        required_skill_level,
        required_reputation_key,
        required_reputation_min,
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
        reward_skill_key,
        reward_skill_xp,
        reward_reputation_key,
        reward_reputation_delta,
        required_skill_key,
        required_skill_level,
        required_reputation_key,
        required_reputation_min,
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

local SELECT_ROUTE_TEMPLATES_WITH_LOCATIONS_QUERY = [[
    SELECT
        rt.id,
        rt.key,
        rt.name,
        rt.description,
        rt.item_key,
        rt.item_quantity,
        rt.reward_money,
        rt.reward_skill_key,
        rt.reward_skill_xp,
        rt.reward_reputation_key,
        rt.reward_reputation_delta,
        rt.required_skill_key,
        rt.required_skill_level,
        rt.required_reputation_key,
        rt.required_reputation_min,
        rt.pickup_location_key,
        rt.delivery_location_key,
        rt.deadline_seconds,
        rt.is_active,
        rt.created_at,
        rt.updated_at,
        pickup.id AS pickup_id,
        pickup.key AS pickup_key,
        pickup.name AS pickup_name,
        pickup.description AS pickup_description,
        pickup.location_type AS pickup_location_type,
        pickup.position_x AS pickup_position_x,
        pickup.position_y AS pickup_position_y,
        pickup.position_z AS pickup_position_z,
        pickup.radius AS pickup_radius,
        pickup.is_active AS pickup_is_active,
        pickup.created_at AS pickup_created_at,
        pickup.updated_at AS pickup_updated_at,
        delivery.id AS delivery_id,
        delivery.key AS delivery_key,
        delivery.name AS delivery_name,
        delivery.description AS delivery_description,
        delivery.location_type AS delivery_location_type,
        delivery.position_x AS delivery_position_x,
        delivery.position_y AS delivery_position_y,
        delivery.position_z AS delivery_position_z,
        delivery.radius AS delivery_radius,
        delivery.is_active AS delivery_is_active,
        delivery.created_at AS delivery_created_at,
        delivery.updated_at AS delivery_updated_at
    FROM contract_route_templates rt
    LEFT JOIN contract_delivery_locations pickup
        ON pickup.key = rt.pickup_location_key
    LEFT JOIN contract_delivery_locations delivery
        ON delivery.key = rt.delivery_location_key
    ORDER BY rt.key ASC
]]

local SELECT_ACTIVE_ROUTE_TEMPLATES_WITH_LOCATIONS_QUERY = [[
    SELECT
        rt.id,
        rt.key,
        rt.name,
        rt.description,
        rt.item_key,
        rt.item_quantity,
        rt.reward_money,
        rt.reward_skill_key,
        rt.reward_skill_xp,
        rt.reward_reputation_key,
        rt.reward_reputation_delta,
        rt.required_skill_key,
        rt.required_skill_level,
        rt.required_reputation_key,
        rt.required_reputation_min,
        rt.pickup_location_key,
        rt.delivery_location_key,
        rt.deadline_seconds,
        rt.is_active,
        rt.created_at,
        rt.updated_at,
        pickup.id AS pickup_id,
        pickup.key AS pickup_key,
        pickup.name AS pickup_name,
        pickup.description AS pickup_description,
        pickup.location_type AS pickup_location_type,
        pickup.position_x AS pickup_position_x,
        pickup.position_y AS pickup_position_y,
        pickup.position_z AS pickup_position_z,
        pickup.radius AS pickup_radius,
        pickup.is_active AS pickup_is_active,
        pickup.created_at AS pickup_created_at,
        pickup.updated_at AS pickup_updated_at,
        delivery.id AS delivery_id,
        delivery.key AS delivery_key,
        delivery.name AS delivery_name,
        delivery.description AS delivery_description,
        delivery.location_type AS delivery_location_type,
        delivery.position_x AS delivery_position_x,
        delivery.position_y AS delivery_position_y,
        delivery.position_z AS delivery_position_z,
        delivery.radius AS delivery_radius,
        delivery.is_active AS delivery_is_active,
        delivery.created_at AS delivery_created_at,
        delivery.updated_at AS delivery_updated_at
    FROM contract_route_templates rt
    LEFT JOIN contract_delivery_locations pickup
        ON pickup.key = rt.pickup_location_key
    LEFT JOIN contract_delivery_locations delivery
        ON delivery.key = rt.delivery_location_key
    WHERE rt.is_active = true
    ORDER BY rt.key ASC
]]

local INSERT_ROUTE_TEMPLATE_QUERY = [[
    INSERT INTO contract_route_templates (
        key,
        name,
        description,
        item_key,
        item_quantity,
        reward_money,
        reward_skill_key,
        reward_skill_xp,
        reward_reputation_key,
        reward_reputation_delta,
        required_skill_key,
        required_skill_level,
        required_reputation_key,
        required_reputation_min,
        pickup_location_key,
        delivery_location_key,
        deadline_seconds,
        is_active
    )
    VALUES (
        :0,
        :1,
        :2,
        :3,
        :4,
        :5,
        NULL,
        0,
        NULL,
        0,
        NULL,
        0,
        NULL,
        0,
        :6,
        :7,
        NULL,
        :8
    )
    RETURNING
        id,
        key,
        name,
        description,
        item_key,
        item_quantity,
        reward_money,
        reward_skill_key,
        reward_skill_xp,
        reward_reputation_key,
        reward_reputation_delta,
        required_skill_key,
        required_skill_level,
        required_reputation_key,
        required_reputation_min,
        pickup_location_key,
        delivery_location_key,
        deadline_seconds,
        is_active,
        created_at,
        updated_at
]]

local UPDATE_ROUTE_ACTIVE_QUERY = [[
    UPDATE contract_route_templates
    SET
        is_active = :1,
        updated_at = NOW()
    WHERE key = :0
    RETURNING
        id,
        key,
        name,
        description,
        item_key,
        item_quantity,
        reward_money,
        reward_skill_key,
        reward_skill_xp,
        reward_reputation_key,
        reward_reputation_delta,
        required_skill_key,
        required_skill_level,
        required_reputation_key,
        required_reputation_min,
        pickup_location_key,
        delivery_location_key,
        deadline_seconds,
        is_active,
        created_at,
        updated_at
]]

local UPDATE_ROUTE_DEADLINE_QUERY = [[
    UPDATE contract_route_templates
    SET
        deadline_seconds = :1,
        updated_at = NOW()
    WHERE key = :0
    RETURNING
        id,
        key,
        name,
        description,
        item_key,
        item_quantity,
        reward_money,
        reward_skill_key,
        reward_skill_xp,
        reward_reputation_key,
        reward_reputation_delta,
        required_skill_key,
        required_skill_level,
        required_reputation_key,
        required_reputation_min,
        pickup_location_key,
        delivery_location_key,
        deadline_seconds,
        is_active,
        created_at,
        updated_at
]]

local UPDATE_ROUTE_REWARD_QUERY = [[
    UPDATE contract_route_templates
    SET
        reward_money = :1,
        reward_skill_xp = :2,
        updated_at = NOW()
    WHERE key = :0
    RETURNING
        id,
        key,
        name,
        description,
        item_key,
        item_quantity,
        reward_money,
        reward_skill_key,
        reward_skill_xp,
        reward_reputation_key,
        reward_reputation_delta,
        required_skill_key,
        required_skill_level,
        required_reputation_key,
        required_reputation_min,
        pickup_location_key,
        delivery_location_key,
        deadline_seconds,
        is_active,
        created_at,
        updated_at
]]

local UPDATE_ROUTE_REQUIREMENT_QUERY = [[
    UPDATE contract_route_templates
    SET
        required_skill_key = :1,
        required_skill_level = :2,
        updated_at = NOW()
    WHERE key = :0
    RETURNING
        id,
        key,
        name,
        description,
        item_key,
        item_quantity,
        reward_money,
        reward_skill_key,
        reward_skill_xp,
        reward_reputation_key,
        reward_reputation_delta,
        required_skill_key,
        required_skill_level,
        required_reputation_key,
        required_reputation_min,
        pickup_location_key,
        delivery_location_key,
        deadline_seconds,
        is_active,
        created_at,
        updated_at
]]

local UPDATE_ROUTE_DESCRIPTION_QUERY = [[
    UPDATE contract_route_templates
    SET
        description = :1,
        updated_at = NOW()
    WHERE key = :0
    RETURNING
        id,
        key,
        name,
        description,
        item_key,
        item_quantity,
        reward_money,
        reward_skill_key,
        reward_skill_xp,
        reward_reputation_key,
        reward_reputation_delta,
        required_skill_key,
        required_skill_level,
        required_reputation_key,
        required_reputation_min,
        pickup_location_key,
        delivery_location_key,
        deadline_seconds,
        is_active,
        created_at,
        updated_at
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
        reward_skill_key,
        reward_skill_xp,
        reward_reputation_key,
        reward_reputation_delta,
        rewards_status,
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
        :14,
        :15,
        :16,
        :17,
        :18,
        CASE
            WHEN :18 IS NULL THEN NULL
            ELSE NOW() + (:18 * INTERVAL '1 second')
        END,
        :19,
        :20,
        'open',
        :21
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

local SELECT_ACTIVE_CONTRACTS_BY_CHARACTER_QUERY = [[
    SELECT
]] .. CONTRACT_SELECT_COLUMNS .. [[
        ,
        CASE
            WHEN expires_at IS NULL THEN NULL
            WHEN expires_at <= NOW() THEN 0
            ELSE CEIL(EXTRACT(EPOCH FROM (expires_at - NOW())))
        END AS remaining_deadline_seconds
    FROM contracts
    WHERE assignee_character_id = :0
      AND status = 'accepted'
      AND COALESCE(payment_status, 'pending') <> 'paid'
    ORDER BY COALESCE(accepted_at, created_at) DESC, id DESC
]]

local SELECT_ACTIVE_CONTRACT_BY_ID_FOR_CHARACTER_QUERY = [[
    SELECT
]] .. CONTRACT_SELECT_COLUMNS .. [[
        ,
        CASE
            WHEN expires_at IS NULL THEN NULL
            WHEN expires_at <= NOW() THEN 0
            ELSE CEIL(EXTRACT(EPOCH FROM (expires_at - NOW())))
        END AS remaining_deadline_seconds
    FROM contracts
    WHERE id = :0
      AND assignee_character_id = :1
      AND status = 'accepted'
      AND COALESCE(payment_status, 'pending') <> 'paid'
    LIMIT 1
]]

local SELECT_JOB_STATS_FOR_CHARACTER_QUERY = [[
    SELECT
        COUNT(*) FILTER (WHERE status = 'completed') AS completed_count,
        COUNT(*) FILTER (WHERE status = 'accepted') AS active_count,
        COUNT(*) FILTER (WHERE status = 'cancelled') AS cancelled_count,
        COUNT(*) FILTER (WHERE status = 'cancelled' AND cancel_reason = 'abandoned') AS abandoned_count,
        COUNT(*) FILTER (WHERE status = 'expired') AS expired_count,
        COUNT(*) FILTER (WHERE status IN ('completed', 'cancelled', 'expired')) AS terminal_count,
        COUNT(*) AS total_count,
        COALESCE(SUM(CASE
            WHEN status = 'completed' AND COALESCE(payment_status, 'pending') = 'paid' THEN reward_money
            ELSE 0
        END), 0) AS money_earned,
        COALESCE(SUM(CASE
            WHEN rewards_status = 'granted' THEN reward_skill_xp
            ELSE 0
        END), 0) AS granted_skill_xp
    FROM contracts
    WHERE assignee_character_id = :0
      AND (
          source_route_key IS NOT NULL
          OR job_source IN ('route_template', 'job_board')
          OR requires_pickup_location = true
      )
]]

local SELECT_JOB_HISTORY_FOR_CHARACTER_QUERY = [[
    SELECT
]] .. CONTRACT_SELECT_COLUMNS .. [[
    FROM contracts
    WHERE assignee_character_id = :0
      AND (
          source_route_key IS NOT NULL
          OR job_source IN ('route_template', 'job_board')
          OR requires_pickup_location = true
      )
    ORDER BY COALESCE(completed_at, cancelled_at, expired_at, accepted_at, created_at) DESC, id DESC
    LIMIT :1
]]

local SELECT_CONTRACT_BY_ID_QUERY = [[
    SELECT
]] .. CONTRACT_SELECT_COLUMNS .. [[
    FROM contracts
    WHERE id = :0
    LIMIT 1
]]

local SELECT_EXPIRED_CONTRACTS_QUERY = [[
    SELECT
]] .. CONTRACT_SELECT_COLUMNS .. [[
    FROM contracts
    WHERE status = 'expired'
    ORDER BY id DESC
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
        expired_at = NOW(),
        cargo_cleanup_status = CASE
            WHEN pickup_status = 'picked_up' THEN 'pending'
            ELSE 'not_required'
        END,
        cargo_cleaned_at = NULL,
        cargo_cleanup_error = NULL
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
        expired_at = NOW(),
        cargo_cleanup_status = CASE
            WHEN pickup_status = 'picked_up' THEN 'pending'
            ELSE 'not_required'
        END,
        cargo_cleaned_at = NULL,
        cargo_cleanup_error = NULL
    WHERE status IN ('open', 'accepted')
      AND expires_at IS NOT NULL
      AND expires_at < NOW()
      AND COALESCE(payment_status, 'pending') <> 'paid'
    RETURNING
]] .. CONTRACT_SELECT_COLUMNS .. [[
]]

local UPDATE_CARGO_CLEANUP_STATUS_QUERY = [[
    UPDATE contracts
    SET
        cargo_cleanup_status = :1,
        cargo_cleaned_at = CASE
            WHEN :1 = 'cleaned' THEN NOW()
            ELSE cargo_cleaned_at
        END,
        cargo_cleanup_error = CASE
            WHEN :1 = 'failed' THEN :2
            ELSE NULL
        END
    WHERE id = :0
    RETURNING
]] .. CONTRACT_SELECT_COLUMNS .. [[
]]

local UPDATE_CONTRACT_REWARDS_STATUS_QUERY = [[
    UPDATE contracts
    SET
        rewards_status = :1,
        rewards_error = :2,
        rewards_granted_at = CASE
            WHEN :1 = 'granted' THEN NOW()
            ELSE rewards_granted_at
        END
    WHERE id = :0
    RETURNING
]] .. CONTRACT_SELECT_COLUMNS .. [[
]]

local MARK_CONTRACT_REWARDS_GRANTED_QUERY = [[
    UPDATE contracts
    SET
        rewards_status = 'granted',
        rewards_granted_at = NOW(),
        rewards_error = NULL
    WHERE id = :0
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

local INSERT_CONTRACT_REWARD_GRANT_QUERY = [[
    INSERT INTO contract_reward_grants (
        contract_id,
        character_id,
        reward_type,
        reward_key,
        amount,
        status,
        error_message,
        applied_at
    )
    VALUES (
        :0,
        :1,
        :2,
        :3,
        :4,
        :5,
        :6,
        CASE
            WHEN :5 = 'applied' THEN NOW()
            ELSE NULL
        END
    )
    ON CONFLICT (contract_id, reward_type, reward_key) DO NOTHING
    RETURNING
]] .. CONTRACT_REWARD_GRANT_SELECT_COLUMNS .. [[
]]

local SELECT_CONTRACT_REWARD_GRANT_QUERY = [[
    SELECT
]] .. CONTRACT_REWARD_GRANT_SELECT_COLUMNS .. [[
    FROM contract_reward_grants
    WHERE contract_id = :0
      AND reward_type = :1
      AND reward_key = :2
    LIMIT 1
]]

local SELECT_CONTRACT_REWARD_GRANTS_BY_CONTRACT_QUERY = [[
    SELECT
]] .. CONTRACT_REWARD_GRANT_SELECT_COLUMNS .. [[
    FROM contract_reward_grants
    WHERE contract_id = :0
    ORDER BY id ASC
]]

local SELECT_RETRYABLE_CONTRACT_REWARD_GRANTS_BY_CONTRACT_QUERY = [[
    SELECT
]] .. CONTRACT_REWARD_GRANT_SELECT_COLUMNS .. [[
    FROM contract_reward_grants
    WHERE contract_id = :0
      AND status IN ('pending', 'failed')
    ORDER BY id ASC
]]

local SELECT_RETRYABLE_CONTRACT_REWARD_GRANTS_QUERY = [[
    SELECT
]] .. CONTRACT_REWARD_GRANT_SELECT_COLUMNS .. [[
    FROM contract_reward_grants
    WHERE status IN ('pending', 'failed')
    ORDER BY updated_at ASC, id ASC
    LIMIT :0
]]

local UPDATE_CONTRACT_REWARD_GRANT_APPLIED_QUERY = [[
    UPDATE contract_reward_grants
    SET
        status = 'applied',
        error_message = NULL,
        updated_at = NOW(),
        applied_at = NOW()
    WHERE id = :0
    RETURNING
]] .. CONTRACT_REWARD_GRANT_SELECT_COLUMNS .. [[
]]

local UPDATE_CONTRACT_REWARD_GRANT_FAILED_QUERY = [[
    UPDATE contract_reward_grants
    SET
        status = 'failed',
        error_message = :1,
        updated_at = NOW()
    WHERE id = :0
    RETURNING
]] .. CONTRACT_REWARD_GRANT_SELECT_COLUMNS .. [[
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

    if #normalized_location_key > 100 then
        return nil
    end

    if normalized_location_key:match("^[a-z0-9_-]+$") == nil then
        return nil
    end

    return string.lower(normalized_location_key)
end

local function normalize_route_key(route_key)
    local normalized_route_key = trim_string(route_key)

    if normalized_route_key == nil then
        return nil
    end

    if normalized_route_key:match("^[a-z0-9_-]+$") == nil then
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

local function normalize_reward_skill_key(reward_skill_key)
    local normalized_reward_skill_key = trim_string(reward_skill_key)

    if normalized_reward_skill_key == nil then
        return nil
    end

    if normalized_reward_skill_key:match("^[a-z0-9_]+$") == nil then
        return nil
    end

    return string.lower(normalized_reward_skill_key)
end

local function normalize_reward_reputation_key(reward_reputation_key)
    local normalized_reward_reputation_key = trim_string(reward_reputation_key)

    if normalized_reward_reputation_key == nil then
        return nil
    end

    if normalized_reward_reputation_key:match("^[a-z0-9_]+$") == nil then
        return nil
    end

    return string.lower(normalized_reward_reputation_key)
end

local function normalize_cargo_cleanup_status(cargo_cleanup_status)
    local normalized_cargo_cleanup_status = trim_string(cargo_cleanup_status)

    if normalized_cargo_cleanup_status == nil then
        return "none"
    end

    normalized_cargo_cleanup_status = string.lower(normalized_cargo_cleanup_status)

    if normalized_cargo_cleanup_status ~= "none"
        and normalized_cargo_cleanup_status ~= "not_required"
        and normalized_cargo_cleanup_status ~= "pending"
        and normalized_cargo_cleanup_status ~= "cleaned"
        and normalized_cargo_cleanup_status ~= "failed"
    then
        return "none"
    end

    return normalized_cargo_cleanup_status
end

local function normalize_rewards_status(rewards_status)
    local normalized_rewards_status = trim_string(rewards_status)

    if normalized_rewards_status == nil then
        return "none"
    end

    normalized_rewards_status = string.lower(normalized_rewards_status)

    if normalized_rewards_status ~= "none"
        and normalized_rewards_status ~= "pending"
        and normalized_rewards_status ~= "granted"
        and normalized_rewards_status ~= "failed"
        and normalized_rewards_status ~= "not_required"
    then
        return "none"
    end

    return normalized_rewards_status
end

local function normalize_reward_grant_type(reward_type)
    local normalized_reward_type = trim_string(reward_type)

    if normalized_reward_type == nil then
        return nil
    end

    normalized_reward_type = string.lower(normalized_reward_type)

    if normalized_reward_type ~= "money"
        and normalized_reward_type ~= "skill_xp"
        and normalized_reward_type ~= "reputation"
    then
        return nil
    end

    return normalized_reward_type
end

local function normalize_reward_grant_key(reward_key)
    local normalized_reward_key = trim_string(reward_key)

    if normalized_reward_key == nil then
        return nil
    end

    if #normalized_reward_key > 128 then
        return nil
    end

    if normalized_reward_key:match("^[a-z0-9_:-]+$") == nil then
        return nil
    end

    return string.lower(normalized_reward_key)
end

local function normalize_reward_grant_status(status)
    local normalized_status = trim_string(status)

    if normalized_status == nil then
        return "pending"
    end

    normalized_status = string.lower(normalized_status)

    if normalized_status ~= "pending"
        and normalized_status ~= "applied"
        and normalized_status ~= "failed"
    then
        return "pending"
    end

    return normalized_status
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
        reward_skill_key = normalize_reward_skill_key(row.reward_skill_key),
        reward_skill_xp = normalize_non_negative_integer(row.reward_skill_xp, 0),
        reward_reputation_key = normalize_reward_reputation_key(row.reward_reputation_key),
        reward_reputation_delta = normalize_integer(row.reward_reputation_delta, 0),
        rewards_status = normalize_rewards_status(row.rewards_status),
        rewards_granted_at = row.rewards_granted_at,
        rewards_error = trim_string(row.rewards_error),
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
        cargo_cleanup_status = normalize_cargo_cleanup_status(row.cargo_cleanup_status),
        cargo_cleaned_at = row.cargo_cleaned_at,
        cargo_cleanup_error = trim_string(row.cargo_cleanup_error),
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
        remaining_deadline_seconds = normalize_integer(row.remaining_deadline_seconds, nil),
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
        reward_skill_key = normalize_reward_skill_key(row.reward_skill_key),
        reward_skill_xp = normalize_non_negative_integer(row.reward_skill_xp, 0),
        reward_reputation_key = normalize_reward_reputation_key(row.reward_reputation_key),
        reward_reputation_delta = normalize_integer(row.reward_reputation_delta, 0),
        required_skill_key = normalize_reward_skill_key(row.required_skill_key),
        required_skill_level = normalize_non_negative_integer(row.required_skill_level, 0),
        required_reputation_key = normalize_reward_reputation_key(row.required_reputation_key),
        required_reputation_min = normalize_integer(row.required_reputation_min, 0),
        pickup_location_key = normalize_location_key(row.pickup_location_key),
        delivery_location_key = normalize_location_key(row.delivery_location_key),
        deadline_seconds = normalize_positive_integer(row.deadline_seconds),
        is_active = normalize_boolean(row.is_active, true),
        created_at = row.created_at,
        updated_at = row.updated_at,
    }
end

local function normalize_contract_reward_grant_row(row)
    local grant_id = nil
    local contract_id = nil
    local character_id = nil
    local reward_type = nil
    local reward_key = nil
    local amount = nil

    if type(row) ~= "table" then
        return nil
    end

    grant_id = normalize_positive_integer(row.id)
    contract_id = normalize_positive_integer(row.contract_id)
    character_id = normalize_positive_integer(row.character_id)
    reward_type = normalize_reward_grant_type(row.reward_type)
    reward_key = normalize_reward_grant_key(row.reward_key)
    amount = normalize_positive_integer(row.amount)

    if grant_id == nil
        or contract_id == nil
        or character_id == nil
        or reward_type == nil
        or reward_key == nil
        or amount == nil
    then
        return nil
    end

    return {
        id = grant_id,
        contract_id = contract_id,
        character_id = character_id,
        reward_type = reward_type,
        reward_key = reward_key,
        amount = amount,
        status = normalize_reward_grant_status(row.status),
        error_message = trim_string(row.error_message),
        created_at = row.created_at,
        updated_at = row.updated_at,
        applied_at = row.applied_at,
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

local function normalize_route_health_location(row, prefix)
    local normalized_prefix = trim_string(prefix)
    local location_id = nil
    local location_key = nil

    if type(row) ~= "table" or normalized_prefix == nil then
        return nil
    end

    location_id = normalize_positive_integer(row[normalized_prefix .. "_id"])
    location_key = normalize_location_key(row[normalized_prefix .. "_key"])

    if location_id == nil or location_key == nil then
        return nil
    end

    return {
        id = location_id,
        key = location_key,
        name = trim_string(row[normalized_prefix .. "_name"]) or location_key,
        description = trim_string(row[normalized_prefix .. "_description"]) or "",
        location_type = trim_string(row[normalized_prefix .. "_location_type"]) or "delivery",
        position_x = normalize_number(row[normalized_prefix .. "_position_x"], nil),
        position_y = normalize_number(row[normalized_prefix .. "_position_y"], nil),
        position_z = normalize_number(row[normalized_prefix .. "_position_z"], nil),
        radius = normalize_number(row[normalized_prefix .. "_radius"], nil),
        is_active = normalize_boolean(row[normalized_prefix .. "_is_active"], true),
        created_at = row[normalized_prefix .. "_created_at"],
        updated_at = row[normalized_prefix .. "_updated_at"],
    }
end

local function normalize_route_health_row(row)
    local route_template = normalize_route_template_row(row)

    if route_template == nil then
        return nil
    end

    return {
        route = route_template,
        raw_route = {
            key = trim_string(row.key),
            item_key = trim_string(row.item_key),
            item_quantity = row.item_quantity,
            reward_money = row.reward_money,
            reward_skill_xp = row.reward_skill_xp,
            required_skill_level = row.required_skill_level,
            required_reputation_min = row.required_reputation_min,
            deadline_seconds = row.deadline_seconds,
            pickup_location_key = trim_string(row.pickup_location_key),
            delivery_location_key = trim_string(row.delivery_location_key),
        },
        pickup_location = normalize_route_health_location(row, "pickup"),
        delivery_location = normalize_route_health_location(row, "delivery"),
    }
end

local function normalize_route_health_rows(rows)
    local normalized_rows = {}

    for _, row in ipairs(rows or {}) do
        local normalized_row = normalize_route_health_row(row)

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

local function normalize_contract_reward_grant_rows(rows)
    local normalized_rows = {}

    for _, row in ipairs(rows or {}) do
        local normalized_row = normalize_contract_reward_grant_row(row)

        if normalized_row ~= nil then
            normalized_rows[#normalized_rows + 1] = normalized_row
        end
    end

    return normalized_rows
end

local function normalize_job_stats_row(row)
    if type(row) ~= "table" then
        return {
            completed_count = 0,
            active_count = 0,
            cancelled_count = 0,
            abandoned_count = 0,
            expired_count = 0,
            terminal_count = 0,
            total_count = 0,
            money_earned = 0,
            granted_skill_xp = 0,
        }
    end

    return {
        completed_count = normalize_non_negative_integer(row.completed_count, 0),
        active_count = normalize_non_negative_integer(row.active_count, 0),
        cancelled_count = normalize_non_negative_integer(row.cancelled_count, 0),
        abandoned_count = normalize_non_negative_integer(row.abandoned_count, 0),
        expired_count = normalize_non_negative_integer(row.expired_count, 0),
        terminal_count = normalize_non_negative_integer(row.terminal_count, 0),
        total_count = normalize_non_negative_integer(row.total_count, 0),
        money_earned = normalize_non_negative_integer(row.money_earned, 0),
        granted_skill_xp = normalize_non_negative_integer(row.granted_skill_xp, 0),
    }
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
    local normalized_reward_skill_key = normalize_reward_skill_key(contract and contract.reward_skill_key)
    local normalized_reward_skill_xp = normalize_non_negative_integer(contract and contract.reward_skill_xp, 0)
    local normalized_reward_reputation_key = normalize_reward_reputation_key(contract and contract.reward_reputation_key)
    local normalized_reward_reputation_delta = normalize_integer(contract and contract.reward_reputation_delta, 0)
    local normalized_rewards_status = normalize_rewards_status(contract and contract.rewards_status)
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

    if contract ~= nil and contract.reward_skill_key ~= nil and normalized_reward_skill_key == nil then
        callback(false, nil, "reward-skill-key-invalid")
        return true
    end

    if contract ~= nil and contract.reward_skill_xp ~= nil and normalized_reward_skill_xp == nil then
        callback(false, nil, "reward-skill-xp-invalid")
        return true
    end

    if contract ~= nil and contract.reward_reputation_key ~= nil and normalized_reward_reputation_key == nil then
        callback(false, nil, "reward-reputation-key-invalid")
        return true
    end

    if contract ~= nil and contract.reward_reputation_delta ~= nil and normalized_reward_reputation_delta == nil then
        callback(false, nil, "reward-reputation-delta-invalid")
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
            normalized_reward_skill_key,
            normalized_reward_skill_xp,
            normalized_reward_reputation_key,
            normalized_reward_reputation_delta,
            normalized_rewards_status,
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

function ContractRepository:ListAllContractLocations(callback)
    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    return self:ListDeliveryLocations(callback)
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

function ContractRepository:ListAllRouteTemplates(callback)
    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    return self:ListRouteTemplates(callback)
end

function ContractRepository:ListRouteTemplatesWithLocations(include_inactive, callback)
    local query = SELECT_ACTIVE_ROUTE_TEMPLATES_WITH_LOCATIONS_QUERY

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if include_inactive == true then
        query = SELECT_ROUTE_TEMPLATES_WITH_LOCATIONS_QUERY
    end

    return self:Connect(function(is_connected, database_or_error, error)
        if not is_connected then
            callback(false, nil, error)
            return
        end

        database_or_error:SelectAsync(query, function(rows, select_error)
            if select_error ~= nil then
                callback(false, nil, select_error)
                return
            end

            callback(true, normalize_route_health_rows(rows), nil)
        end)
    end, "contracts-list-route-templates-with-locations")
end

function ContractRepository:ListRoutesUsingLocation(location_key, callback)
    local normalized_location_key = normalize_location_key(location_key)

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if normalized_location_key == nil then
        callback(false, nil, "delivery-location-key-required")
        return true
    end

    return self:ListRouteTemplatesWithLocations(true, function(is_success, route_rows, error)
        local matching_rows = {}

        if not is_success then
            callback(false, nil, error)
            return
        end

        for _, route_row in ipairs(route_rows or {}) do
            local route_template = route_row and route_row.route or nil
            local uses_pickup = normalize_location_key(route_template and route_template.pickup_location_key) == normalized_location_key
            local uses_delivery = normalize_location_key(route_template and route_template.delivery_location_key) == normalized_location_key
            local usage = nil

            if uses_pickup and uses_delivery then
                usage = "pickup,destination"
            elseif uses_pickup then
                usage = "pickup"
            elseif uses_delivery then
                usage = "destination"
            end

            if usage ~= nil then
                matching_rows[#matching_rows + 1] = {
                    route = route_template,
                    raw_route = route_row.raw_route,
                    pickup_location = route_row.pickup_location,
                    delivery_location = route_row.delivery_location,
                    usage = usage,
                }
            end
        end

        callback(true, matching_rows, nil)
    end)
end

function ContractRepository:ListUnusedContractLocations(callback)
    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    return self:ListAllContractLocations(function(is_locations_success, delivery_locations, locations_error)
        if not is_locations_success then
            callback(false, nil, locations_error)
            return
        end

        self:ListRouteTemplates(function(is_routes_success, route_templates, routes_error)
            local used_location_keys = {}
            local unused_locations = {}

            if not is_routes_success then
                callback(false, nil, routes_error)
                return
            end

            for _, route_template in ipairs(route_templates or {}) do
                local pickup_location_key = normalize_location_key(route_template and route_template.pickup_location_key)
                local delivery_location_key = normalize_location_key(route_template and route_template.delivery_location_key)

                if pickup_location_key ~= nil then
                    used_location_keys[pickup_location_key] = true
                end

                if delivery_location_key ~= nil then
                    used_location_keys[delivery_location_key] = true
                end
            end

            for _, delivery_location in ipairs(delivery_locations or {}) do
                if used_location_keys[normalize_location_key(delivery_location and delivery_location.key)] ~= true then
                    unused_locations[#unused_locations + 1] = delivery_location
                end
            end

            callback(true, unused_locations, nil)
        end)
    end)
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

function ContractRepository:CreateRouteTemplate(route, callback)
    local normalized_route_key = normalize_route_key(route and route.key)
    local normalized_name = trim_string(route and route.name)
    local normalized_description = trim_string(route and route.description)
    local normalized_item_key = normalize_item_key(route and route.item_key)
    local normalized_item_quantity = normalize_positive_integer(route and route.item_quantity)
    local normalized_reward_money = normalize_non_negative_integer(route and route.reward_money, nil)
    local normalized_pickup_location_key = normalize_location_key(route and route.pickup_location_key)
    local normalized_delivery_location_key = normalize_location_key(route and route.delivery_location_key)
    local normalized_is_active = normalize_boolean(route and route.is_active, nil)

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if normalized_route_key == nil then
        callback(false, nil, "route-key-required")
        return true
    end

    if normalized_name == nil then
        callback(false, nil, "route-name-required")
        return true
    end

    if normalized_description == nil then
        callback(false, nil, "route-description-required")
        return true
    end

    if normalized_item_key == nil then
        callback(false, nil, "item-key-invalid")
        return true
    end

    if normalized_item_quantity == nil then
        callback(false, nil, "item-quantity-invalid")
        return true
    end

    if normalized_reward_money == nil then
        callback(false, nil, "reward-money-invalid")
        return true
    end

    if normalized_pickup_location_key == nil then
        callback(false, nil, "pickup-location-key-invalid")
        return true
    end

    if normalized_delivery_location_key == nil then
        callback(false, nil, "delivery-location-key-invalid")
        return true
    end

    if normalized_is_active == nil then
        callback(false, nil, "route-active-invalid")
        return true
    end

    return self:Connect(function(is_connected, database_or_error, error)
        if not is_connected then
            callback(false, nil, error)
            return
        end

        database_or_error:SelectAsync(
            INSERT_ROUTE_TEMPLATE_QUERY,
            function(rows, insert_error)
                local route_templates = nil
                local error_message = insert_error

                if type(error_message) == "string" and string.find(string.lower(error_message), "duplicate", 1, true) ~= nil then
                    callback(false, nil, "route-already-exists")
                    return
                end

                if insert_error ~= nil then
                    callback(false, nil, insert_error)
                    return
                end

                route_templates = normalize_route_template_rows(rows)
                callback(true, route_templates[1], nil)
            end,
            normalized_route_key,
            normalized_name,
            normalized_description,
            normalized_item_key,
            normalized_item_quantity,
            normalized_reward_money,
            normalized_pickup_location_key,
            normalized_delivery_location_key,
            normalized_is_active
        )
    end, "contracts-create-route-template")
end

function ContractRepository:UpdateRouteActive(route_key, is_active, callback)
    local normalized_route_key = normalize_route_key(route_key)
    local normalized_is_active = normalize_boolean(is_active, nil)

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if normalized_route_key == nil then
        callback(false, nil, "route-key-required")
        return true
    end

    if normalized_is_active == nil then
        callback(false, nil, "route-active-invalid")
        return true
    end

    return self:Connect(function(is_connected, database_or_error, error)
        if not is_connected then
            callback(false, nil, error)
            return
        end

        database_or_error:SelectAsync(UPDATE_ROUTE_ACTIVE_QUERY, function(rows, update_error)
            local route_templates = nil

            if update_error ~= nil then
                callback(false, nil, update_error)
                return
            end

            route_templates = normalize_route_template_rows(rows)
            callback(true, route_templates[1], nil)
        end, normalized_route_key, normalized_is_active)
    end, "contracts-update-route-active")
end

function ContractRepository:UpdateRouteDeadline(route_key, deadline_seconds, callback)
    local normalized_route_key = normalize_route_key(route_key)
    local normalized_deadline_seconds = normalize_positive_integer(deadline_seconds)

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if normalized_route_key == nil then
        callback(false, nil, "route-key-required")
        return true
    end

    if deadline_seconds ~= nil and normalized_deadline_seconds == nil then
        callback(false, nil, "deadline-seconds-invalid")
        return true
    end

    return self:Connect(function(is_connected, database_or_error, error)
        if not is_connected then
            callback(false, nil, error)
            return
        end

        database_or_error:SelectAsync(UPDATE_ROUTE_DEADLINE_QUERY, function(rows, update_error)
            local route_templates = nil

            if update_error ~= nil then
                callback(false, nil, update_error)
                return
            end

            route_templates = normalize_route_template_rows(rows)
            callback(true, route_templates[1], nil)
        end, normalized_route_key, normalized_deadline_seconds)
    end, "contracts-update-route-deadline")
end

function ContractRepository:UpdateRouteReward(route_key, reward_money, reward_skill_xp, callback)
    local normalized_route_key = normalize_route_key(route_key)
    local normalized_reward_money = normalize_non_negative_integer(reward_money, nil)
    local normalized_reward_skill_xp = normalize_non_negative_integer(reward_skill_xp, nil)

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if normalized_route_key == nil then
        callback(false, nil, "route-key-required")
        return true
    end

    if normalized_reward_money == nil then
        callback(false, nil, "reward-money-invalid")
        return true
    end

    if normalized_reward_skill_xp == nil then
        callback(false, nil, "reward-skill-xp-invalid")
        return true
    end

    return self:Connect(function(is_connected, database_or_error, error)
        if not is_connected then
            callback(false, nil, error)
            return
        end

        database_or_error:SelectAsync(UPDATE_ROUTE_REWARD_QUERY, function(rows, update_error)
            local route_templates = nil

            if update_error ~= nil then
                callback(false, nil, update_error)
                return
            end

            route_templates = normalize_route_template_rows(rows)
            callback(true, route_templates[1], nil)
        end, normalized_route_key, normalized_reward_money, normalized_reward_skill_xp)
    end, "contracts-update-route-reward")
end

function ContractRepository:UpdateRouteRequirement(route_key, required_skill_key, required_skill_level, callback)
    local normalized_route_key = normalize_route_key(route_key)
    local normalized_required_skill_key = normalize_reward_skill_key(required_skill_key)
    local normalized_required_skill_level = normalize_non_negative_integer(required_skill_level, nil)

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if normalized_route_key == nil then
        callback(false, nil, "route-key-required")
        return true
    end

    if required_skill_key ~= nil and normalized_required_skill_key == nil then
        callback(false, nil, "required-skill-key-invalid")
        return true
    end

    if normalized_required_skill_level == nil then
        callback(false, nil, "required-skill-level-invalid")
        return true
    end

    return self:Connect(function(is_connected, database_or_error, error)
        if not is_connected then
            callback(false, nil, error)
            return
        end

        database_or_error:SelectAsync(UPDATE_ROUTE_REQUIREMENT_QUERY, function(rows, update_error)
            local route_templates = nil

            if update_error ~= nil then
                callback(false, nil, update_error)
                return
            end

            route_templates = normalize_route_template_rows(rows)
            callback(true, route_templates[1], nil)
        end, normalized_route_key, normalized_required_skill_key, normalized_required_skill_level)
    end, "contracts-update-route-requirement")
end

function ContractRepository:UpdateRouteDescription(route_key, description, callback)
    local normalized_route_key = normalize_route_key(route_key)
    local normalized_description = trim_string(description)

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if normalized_route_key == nil then
        callback(false, nil, "route-key-required")
        return true
    end

    if normalized_description == nil then
        callback(false, nil, "route-description-required")
        return true
    end

    return self:Connect(function(is_connected, database_or_error, error)
        if not is_connected then
            callback(false, nil, error)
            return
        end

        database_or_error:SelectAsync(UPDATE_ROUTE_DESCRIPTION_QUERY, function(rows, update_error)
            local route_templates = nil

            if update_error ~= nil then
                callback(false, nil, update_error)
                return
            end

            route_templates = normalize_route_template_rows(rows)
            callback(true, route_templates[1], nil)
        end, normalized_route_key, normalized_description)
    end, "contracts-update-route-description")
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

function ContractRepository:CreateContractLocation(location, callback)
    local normalized_location_key = normalize_location_key(location and location.key)
    local normalized_name = trim_string(location and location.name)
    local normalized_description = trim_string(location and location.description) or ""
    local normalized_radius = normalize_number(location and location.radius, nil)

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if normalized_location_key == nil then
        callback(false, nil, "delivery-location-key-required")
        return true
    end

    if normalized_name == nil then
        callback(false, nil, "delivery-location-name-required")
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

        database_or_error:SelectAsync(INSERT_CONTRACT_LOCATION_QUERY, function(rows, insert_error)
            local delivery_locations = nil
            local error_message = insert_error

            if type(error_message) == "string" and string.find(string.lower(error_message), "duplicate", 1, true) ~= nil then
                callback(false, nil, "location-already-exists")
                return
            end

            if insert_error ~= nil then
                callback(false, nil, insert_error)
                return
            end

            delivery_locations = normalize_delivery_location_rows(rows)
            callback(true, delivery_locations[1], nil)
        end, normalized_location_key, normalized_name, normalized_description, normalized_radius)
    end, "contracts-create-delivery-location")
end

function ContractRepository:UpdateContractLocationActive(location_key, is_active, callback)
    local normalized_location_key = normalize_location_key(location_key)
    local normalized_is_active = normalize_boolean(is_active, nil)

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if normalized_location_key == nil then
        callback(false, nil, "delivery-location-key-required")
        return true
    end

    if normalized_is_active == nil then
        callback(false, nil, "delivery-location-active-invalid")
        return true
    end

    return self:Connect(function(is_connected, database_or_error, error)
        if not is_connected then
            callback(false, nil, error)
            return
        end

        database_or_error:SelectAsync(UPDATE_CONTRACT_LOCATION_ACTIVE_QUERY, function(rows, update_error)
            local delivery_locations = nil

            if update_error ~= nil then
                callback(false, nil, update_error)
                return
            end

            delivery_locations = normalize_delivery_location_rows(rows)
            callback(true, delivery_locations[1], nil)
        end, normalized_location_key, normalized_is_active)
    end, "contracts-update-delivery-location-active")
end

function ContractRepository:UpdateContractLocationRadius(location_key, radius, callback)
    local normalized_location_key = normalize_location_key(location_key)
    local normalized_radius = normalize_number(radius, nil)

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if normalized_location_key == nil then
        callback(false, nil, "delivery-location-key-required")
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

        database_or_error:SelectAsync(UPDATE_CONTRACT_LOCATION_RADIUS_QUERY, function(rows, update_error)
            local delivery_locations = nil

            if update_error ~= nil then
                callback(false, nil, update_error)
                return
            end

            delivery_locations = normalize_delivery_location_rows(rows)
            callback(true, delivery_locations[1], nil)
        end, normalized_location_key, normalized_radius)
    end, "contracts-update-delivery-location-radius")
end

function ContractRepository:UpdateContractLocationName(location_key, name, callback)
    local normalized_location_key = normalize_location_key(location_key)
    local normalized_name = trim_string(name)

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if normalized_location_key == nil then
        callback(false, nil, "delivery-location-key-required")
        return true
    end

    if normalized_name == nil then
        callback(false, nil, "delivery-location-name-required")
        return true
    end

    return self:Connect(function(is_connected, database_or_error, error)
        if not is_connected then
            callback(false, nil, error)
            return
        end

        database_or_error:SelectAsync(UPDATE_CONTRACT_LOCATION_NAME_QUERY, function(rows, update_error)
            local delivery_locations = nil

            if update_error ~= nil then
                callback(false, nil, update_error)
                return
            end

            delivery_locations = normalize_delivery_location_rows(rows)
            callback(true, delivery_locations[1], nil)
        end, normalized_location_key, normalized_name)
    end, "contracts-update-delivery-location-name")
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

function ContractRepository:ListActiveContractsByCharacter(character_id, callback)
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

        database_or_error:SelectAsync(SELECT_ACTIVE_CONTRACTS_BY_CHARACTER_QUERY, function(rows, select_error)
            if select_error ~= nil then
                callback(false, nil, select_error)
                return
            end

            callback(true, normalize_rows(rows), nil)
        end, normalized_character_id)
    end, "contracts-list-active-character")
end

function ContractRepository:GetCharacterJobStats(character_id, callback)
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

        database_or_error:SelectAsync(SELECT_JOB_STATS_FOR_CHARACTER_QUERY, function(rows, select_error)
            local job_stats_row = nil

            if select_error ~= nil then
                callback(false, nil, select_error)
                return
            end

            if type(rows) == "table" and #rows > 0 then
                job_stats_row = normalize_job_stats_row(rows[1])
            else
                job_stats_row = normalize_job_stats_row(nil)
            end

            callback(true, job_stats_row, nil)
        end, normalized_character_id)
    end, "contracts-job-stats-character")
end

function ContractRepository:ListCharacterJobHistory(character_id, limit, callback)
    local normalized_character_id = normalize_positive_integer(character_id)
    local normalized_limit = normalize_positive_integer(limit)

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if normalized_character_id == nil then
        callback(false, nil, "character-id-required")
        return true
    end

    if normalized_limit == nil then
        callback(false, nil, "limit-required")
        return true
    end

    return self:Connect(function(is_connected, database_or_error, error)
        if not is_connected then
            callback(false, nil, error)
            return
        end

        database_or_error:SelectAsync(SELECT_JOB_HISTORY_FOR_CHARACTER_QUERY, function(rows, select_error)
            if select_error ~= nil then
                callback(false, nil, select_error)
                return
            end

            callback(true, normalize_rows(rows), nil)
        end, normalized_character_id, normalized_limit)
    end, "contracts-job-history-character")
end

function ContractRepository:ListExpiredContracts(callback)
    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    return self:Connect(function(is_connected, database_or_error, error)
        if not is_connected then
            callback(false, nil, error)
            return
        end

        database_or_error:SelectAsync(SELECT_EXPIRED_CONTRACTS_QUERY, function(rows, select_error)
            if select_error ~= nil then
                callback(false, nil, select_error)
                return
            end

            callback(true, normalize_rows(rows), nil)
        end)
    end, "contracts-list-expired")
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

function ContractRepository:GetContractByIdForCharacter(contract_id, character_id, callback)
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

        database_or_error:SelectAsync(SELECT_ACTIVE_CONTRACT_BY_ID_FOR_CHARACTER_QUERY, function(rows, select_error)
            local contract_rows = nil

            if select_error ~= nil then
                callback(false, nil, select_error)
                return
            end

            contract_rows = normalize_rows(rows)
            callback(true, contract_rows[1], nil)
        end, normalized_contract_id, normalized_character_id)
    end, "contracts-get-active-by-id-character")
end

local function resolve_complete_contract_error(contract_row, character_id)
    local normalized_character_id = normalize_positive_integer(character_id)
    local assignee_character_id = normalize_positive_integer(contract_row and contract_row.assignee_character_id)
    local contract_status = normalize_contract_status(contract_row and contract_row.status)
    local requires_pickup_location = contract_row ~= nil and contract_row.requires_pickup_location == true
    local pickup_status = normalize_pickup_status(contract_row and contract_row.pickup_status)

    if type(contract_row) ~= "table" then
        return "contract-not-found"
    end

    if normalized_character_id == nil or assignee_character_id ~= normalized_character_id then
        return "contract-not-found"
    end

    if contract_status == "completed" then
        return "contract-already-completed"
    end

    if contract_status == "cancelled" then
        return "contract-cancelled"
    end

    if contract_status == "expired" then
        return "contract-expired"
    end

    if requires_pickup_location and pickup_status ~= "picked_up" then
        return "cargo-not-picked-up"
    end

    if contract_status ~= "accepted" then
        return "contract-not-found"
    end

    return nil
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

    return self:GetContractById(normalized_contract_id, function(is_get_success, contract_row, get_error)
        if not is_get_success then
            callback(false, nil, get_error)
            return
        end

        if contract_row == nil then
            callback(false, nil, "contract-not-found")
            return
        end

        local precheck_error = resolve_complete_contract_error(contract_row, normalized_character_id)

        if precheck_error ~= nil then
            callback(false, contract_row, precheck_error)
            return
        end

        self:Connect(function(is_connected, database_or_error, error)
            if not is_connected then
                callback(false, contract_row, error)
                return
            end

            database_or_error:SelectAsync(COMPLETE_CONTRACT_QUERY, function(rows, update_error)
                local contract_rows = nil

                if update_error ~= nil then
                    callback(false, contract_row, update_error)
                    return
                end

                contract_rows = normalize_rows(rows)

                if contract_rows[1] ~= nil then
                    callback(true, contract_rows[1], nil)
                    return
                end

                self:GetContractById(normalized_contract_id, function(is_refresh_success, refreshed_row, refresh_error)
                    if not is_refresh_success then
                        callback(false, contract_row, refresh_error or "database-error")
                        return
                    end

                    callback(
                        false,
                        refreshed_row or contract_row,
                        resolve_complete_contract_error(refreshed_row or contract_row, normalized_character_id) or "database-error"
                    )
                end)
            end, normalized_contract_id, normalized_character_id)
        end, "contracts-complete")
    end)
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

function ContractRepository:UpdateCargoCleanupStatus(contract_id, cargo_cleanup_status, error_message, callback)
    local normalized_contract_id = normalize_positive_integer(contract_id)
    local normalized_cargo_cleanup_status = normalize_cargo_cleanup_status(cargo_cleanup_status)
    local normalized_error_message = trim_string(error_message)

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

        database_or_error:SelectAsync(UPDATE_CARGO_CLEANUP_STATUS_QUERY, function(rows, update_error)
            local contract_rows = nil

            if update_error ~= nil then
                callback(false, nil, update_error)
                return
            end

            contract_rows = normalize_rows(rows)
            callback(true, contract_rows[1], nil)
        end, normalized_contract_id, normalized_cargo_cleanup_status, normalized_error_message)
    end, "contracts-update-cargo-cleanup-status")
end

function ContractRepository:UpdateContractRewardsStatus(contract_id, rewards_status, error_message, callback)
    local normalized_contract_id = normalize_positive_integer(contract_id)
    local normalized_rewards_status = normalize_rewards_status(rewards_status)
    local normalized_error_message = trim_string(error_message)

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

        database_or_error:SelectAsync(UPDATE_CONTRACT_REWARDS_STATUS_QUERY, function(rows, update_error)
            local contract_rows = nil

            if update_error ~= nil then
                callback(false, nil, update_error)
                return
            end

            contract_rows = normalize_rows(rows)
            callback(true, contract_rows[1], nil)
        end, normalized_contract_id, normalized_rewards_status, normalized_error_message)
    end, "contracts-update-rewards-status")
end

function ContractRepository:MarkContractRewardsGranted(contract_id, callback)
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

        database_or_error:SelectAsync(MARK_CONTRACT_REWARDS_GRANTED_QUERY, function(rows, update_error)
            local contract_rows = nil

            if update_error ~= nil then
                callback(false, nil, update_error)
                return
            end

            contract_rows = normalize_rows(rows)
            callback(true, contract_rows[1], nil)
        end, normalized_contract_id)
    end, "contracts-mark-rewards-granted")
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

function ContractRepository:FindContractRewardGrant(contract_id, reward_type, reward_key, callback)
    local normalized_contract_id = normalize_positive_integer(contract_id)
    local normalized_reward_type = normalize_reward_grant_type(reward_type)
    local normalized_reward_key = normalize_reward_grant_key(reward_key)

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if normalized_contract_id == nil then
        callback(false, nil, "contract-id-required")
        return true
    end

    if normalized_reward_type == nil then
        callback(false, nil, "reward-type-required")
        return true
    end

    if normalized_reward_key == nil then
        callback(false, nil, "reward-key-required")
        return true
    end

    return self:Connect(function(is_connected, database_or_error, error)
        if not is_connected then
            callback(false, nil, error)
            return
        end

        database_or_error:SelectAsync(SELECT_CONTRACT_REWARD_GRANT_QUERY, function(rows, select_error)
            local grant_rows = nil

            if select_error ~= nil then
                callback(false, nil, select_error)
                return
            end

            grant_rows = normalize_contract_reward_grant_rows(rows)
            callback(true, grant_rows[1], nil)
        end, normalized_contract_id, normalized_reward_type, normalized_reward_key)
    end, "contracts-find-reward-grant")
end

function ContractRepository:GetContractRewardGrants(contract_id, callback)
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

        database_or_error:SelectAsync(SELECT_CONTRACT_REWARD_GRANTS_BY_CONTRACT_QUERY, function(rows, select_error)
            if select_error ~= nil then
                callback(false, nil, select_error)
                return
            end

            callback(true, normalize_contract_reward_grant_rows(rows), nil)
        end, normalized_contract_id)
    end, "contracts-list-reward-grants")
end

function ContractRepository:GetRetryableContractRewardGrants(contract_id, callback)
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

        database_or_error:SelectAsync(SELECT_RETRYABLE_CONTRACT_REWARD_GRANTS_BY_CONTRACT_QUERY, function(rows, select_error)
            if select_error ~= nil then
                callback(false, nil, select_error)
                return
            end

            callback(true, normalize_contract_reward_grant_rows(rows), nil)
        end, normalized_contract_id)
    end, "contracts-list-retryable-reward-grants-by-contract")
end

function ContractRepository:ListRetryableContractRewardGrants(limit, callback)
    local normalized_limit = normalize_positive_integer(limit)

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if normalized_limit == nil then
        callback(false, nil, "limit-required")
        return true
    end

    return self:Connect(function(is_connected, database_or_error, error)
        if not is_connected then
            callback(false, nil, error)
            return
        end

        database_or_error:SelectAsync(SELECT_RETRYABLE_CONTRACT_REWARD_GRANTS_QUERY, function(rows, select_error)
            if select_error ~= nil then
                callback(false, nil, select_error)
                return
            end

            callback(true, normalize_contract_reward_grant_rows(rows), nil)
        end, normalized_limit)
    end, "contracts-list-retryable-reward-grants")
end

function ContractRepository:CreateContractRewardGrant(grant, callback)
    local normalized_contract_id = normalize_positive_integer(grant and grant.contract_id)
    local normalized_character_id = normalize_positive_integer(grant and grant.character_id)
    local normalized_reward_type = normalize_reward_grant_type(grant and grant.reward_type)
    local normalized_reward_key = normalize_reward_grant_key(grant and grant.reward_key)
    local normalized_amount = normalize_positive_integer(grant and grant.amount)
    local normalized_status = normalize_reward_grant_status(grant and grant.status)
    local normalized_error_message = trim_string(grant and grant.error_message)

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

    if normalized_reward_type == nil then
        callback(false, nil, "reward-type-required")
        return true
    end

    if normalized_reward_key == nil then
        callback(false, nil, "reward-key-required")
        return true
    end

    if normalized_amount == nil then
        callback(false, nil, "reward-amount-required")
        return true
    end

    return self:Connect(function(is_connected, database_or_error, error)
        if not is_connected then
            callback(false, nil, error)
            return
        end

        database_or_error:SelectAsync(INSERT_CONTRACT_REWARD_GRANT_QUERY, function(rows, insert_error)
            local grant_rows = nil

            if insert_error ~= nil then
                callback(false, nil, insert_error)
                return
            end

            grant_rows = normalize_contract_reward_grant_rows(rows)

            if grant_rows[1] ~= nil then
                callback(true, grant_rows[1], nil)
                return
            end

            self:FindContractRewardGrant(
                normalized_contract_id,
                normalized_reward_type,
                normalized_reward_key,
                function(is_find_success, existing_grant, find_error)
                    if not is_find_success then
                        callback(false, nil, find_error or "database-error")
                        return
                    end

                    callback(true, existing_grant, nil)
                end
            )
        end,
            normalized_contract_id,
            normalized_character_id,
            normalized_reward_type,
            normalized_reward_key,
            normalized_amount,
            normalized_status,
            normalized_error_message
        )
    end, "contracts-create-reward-grant")
end

function ContractRepository:MarkContractRewardGrantApplied(grant_id, callback)
    local normalized_grant_id = normalize_positive_integer(grant_id)

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if normalized_grant_id == nil then
        callback(false, nil, "grant-id-required")
        return true
    end

    return self:Connect(function(is_connected, database_or_error, error)
        if not is_connected then
            callback(false, nil, error)
            return
        end

        database_or_error:SelectAsync(UPDATE_CONTRACT_REWARD_GRANT_APPLIED_QUERY, function(rows, update_error)
            local grant_rows = nil

            if update_error ~= nil then
                callback(false, nil, update_error)
                return
            end

            grant_rows = normalize_contract_reward_grant_rows(rows)
            callback(true, grant_rows[1], nil)
        end, normalized_grant_id)
    end, "contracts-mark-reward-grant-applied")
end

function ContractRepository:MarkContractRewardGrantFailed(grant_id, error_message, callback)
    local normalized_grant_id = normalize_positive_integer(grant_id)
    local normalized_error_message = trim_string(error_message)

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if normalized_grant_id == nil then
        callback(false, nil, "grant-id-required")
        return true
    end

    return self:Connect(function(is_connected, database_or_error, error)
        if not is_connected then
            callback(false, nil, error)
            return
        end

        database_or_error:SelectAsync(UPDATE_CONTRACT_REWARD_GRANT_FAILED_QUERY, function(rows, update_error)
            local grant_rows = nil

            if update_error ~= nil then
                callback(false, nil, update_error)
                return
            end

            grant_rows = normalize_contract_reward_grant_rows(rows)
            callback(true, grant_rows[1], nil)
        end, normalized_grant_id, normalized_error_message)
    end, "contracts-mark-reward-grant-failed")
end

GRContracts.Server.ContractRepositoryClass = ContractRepository

return ContractRepository

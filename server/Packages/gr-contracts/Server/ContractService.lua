GRContracts = GRContracts or {}
GRContracts.Server = GRContracts.Server or {}

local ContractService = {}
ContractService.__index = ContractService

local MAX_REWARD_MONEY = 1000000
local MAX_DELIVERY_QUANTITY = 1000
local DEFAULT_DELIVERY_LOCATION_RADIUS = 500
local MAX_DELIVERY_LOCATION_RADIUS = 5000

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
        if value < 0 or value > MAX_REWARD_MONEY or value % 1 ~= 0 then
            return nil
        end

        return math.floor(value)
    end

    if type(value) == "string" and value:match("^%d+$") ~= nil then
        local parsed_value = tonumber(value)

        if parsed_value ~= nil and parsed_value >= 0 and parsed_value <= MAX_REWARD_MONEY then
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

local function normalize_number(value)
    if type(value) == "number" then
        if value ~= value or value == math.huge or value == -math.huge then
            return nil
        end

        return value
    end

    if type(value) == "string" then
        local parsed_value = tonumber(value)

        if parsed_value ~= nil and parsed_value == parsed_value and parsed_value ~= math.huge and parsed_value ~= -math.huge then
            return parsed_value
        end
    end

    return nil
end

local function get_controlled_character(player)
    if type(player) ~= "table" and type(player) ~= "userdata" then
        return nil
    end

    if type(player.GetControlledCharacter) ~= "function" then
        return nil
    end

    return player:GetControlledCharacter()
end

local function get_entity_location(entity)
    if entity == nil or type(entity.GetLocation) ~= "function" then
        return nil
    end

    local location = entity:GetLocation()

    if location == nil then
        return nil
    end

    if type(location.X) ~= "number" or type(location.Y) ~= "number" or type(location.Z) ~= "number" then
        return nil
    end

    return {
        x = location.X,
        y = location.Y,
        z = location.Z,
    }
end

local function get_distance_squared(first_location, second_location)
    if type(first_location) ~= "table" or type(second_location) ~= "table" then
        return nil
    end

    local delta_x = first_location.x - second_location.x
    local delta_y = first_location.y - second_location.y
    local delta_z = first_location.z - second_location.z

    return (delta_x * delta_x) + (delta_y * delta_y) + (delta_z * delta_z)
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

local function resolve_economy_bridge()
    if type(GREconomyBridge) ~= "table" then
        return nil
    end

    if type(GREconomyBridge.AddMoney) ~= "function" then
        return nil
    end

    return GREconomyBridge
end

local function resolve_inventory_bridge()
    if type(GRInventoryBridge) ~= "table" then
        return nil
    end

    if type(GRInventoryBridge.ListInventory) ~= "function" then
        return nil
    end

    if type(GRInventoryBridge.RemoveItem) ~= "function" then
        return nil
    end

    if type(GRInventoryBridge.AddItem) ~= "function" then
        return nil
    end

    return GRInventoryBridge
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

local function has_required_items(inventory_rows, required_item_key, required_item_quantity)
    local total_quantity = 0

    for _, inventory_row in ipairs(inventory_rows or {}) do
        if inventory_row.item_key == required_item_key then
            total_quantity = total_quantity + (tonumber(inventory_row.quantity) or 0)
        end
    end

    return total_quantity >= required_item_quantity, total_quantity
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
        required_item_key = nil,
        required_item_quantity = 0,
        consume_required_items = true,
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

function ContractService:CreateDeliveryContract(creator_character_id, item_key, quantity, reward_money, description, callback)
    local normalized_character_id = normalize_positive_integer(creator_character_id)
    local normalized_item_key = normalize_item_key(item_key)
    local normalized_quantity = normalize_positive_integer(quantity)
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

    if normalized_item_key == nil then
        callback(false, nil, "item-key-invalid")
        return true
    end

    if normalized_quantity == nil or normalized_quantity > MAX_DELIVERY_QUANTITY then
        callback(false, nil, "quantity-invalid")
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
        type = "delivery",
        title = build_contract_title("delivery"),
        description = normalized_description,
        reward_money = normalized_reward_money,
        deadline_at = nil,
        required_item_key = normalized_item_key,
        required_item_quantity = normalized_quantity,
        consume_required_items = true,
        delivery_location_key = nil,
        requires_delivery_location = false,
    }, function(is_success, contract_row, error)
        if not is_success then
            callback(false, nil, error)
            return
        end

        Console.Log(
            "[gr_contracts][service] Delivery contract created id=%s creator_character_id=%s item=%s quantity=%s reward_money=%s.",
            tostring(contract_row and contract_row.id),
            tostring(normalized_character_id),
            tostring(normalized_item_key),
            tostring(normalized_quantity),
            tostring(normalized_reward_money)
        )

        callback(true, contract_row, nil)
    end)
end

function ContractService:CreateDeliveryContractAt(creator_character_id, item_key, quantity, reward_money, location_key, description, callback)
    local normalized_character_id = normalize_positive_integer(creator_character_id)
    local normalized_item_key = normalize_item_key(item_key)
    local normalized_quantity = normalize_positive_integer(quantity)
    local normalized_reward_money = normalize_reward_money(reward_money)
    local normalized_location_key = normalize_location_key(location_key)
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

    if normalized_item_key == nil then
        callback(false, nil, "item-key-invalid")
        return true
    end

    if normalized_quantity == nil or normalized_quantity > MAX_DELIVERY_QUANTITY then
        callback(false, nil, "quantity-invalid")
        return true
    end

    if normalized_reward_money == nil then
        callback(false, nil, "reward-money-invalid")
        return true
    end

    if normalized_location_key == nil then
        callback(false, nil, "delivery-location-key-invalid")
        return true
    end

    if normalized_description == nil then
        callback(false, nil, "description-invalid")
        return true
    end

    return self.repository:GetDeliveryLocation(normalized_location_key, function(is_location_success, delivery_location, location_error)
        if not is_location_success then
            callback(false, nil, location_error or "delivery-location-not-found")
            return
        end

        if delivery_location == nil then
            callback(false, nil, "delivery-location-not-found")
            return
        end

        if delivery_location.is_active ~= true then
            callback(false, nil, "delivery-location-inactive")
            return
        end

        self.repository:CreateContract({
            creator_character_id = normalized_character_id,
            type = "delivery",
            title = build_contract_title("delivery"),
            description = normalized_description,
            reward_money = normalized_reward_money,
            deadline_at = nil,
            required_item_key = normalized_item_key,
            required_item_quantity = normalized_quantity,
            consume_required_items = true,
            delivery_location_key = normalized_location_key,
            requires_delivery_location = true,
        }, function(is_success, contract_row, error)
            if not is_success then
                callback(false, nil, error)
                return
            end

            Console.Log(
                "[gr_contracts][service] Delivery contract with location created id=%s creator_character_id=%s item=%s quantity=%s reward_money=%s location=%s.",
                tostring(contract_row and contract_row.id),
                tostring(normalized_character_id),
                tostring(normalized_item_key),
                tostring(normalized_quantity),
                tostring(normalized_reward_money),
                tostring(normalized_location_key)
            )

            callback(true, contract_row, nil)
        end)
    end)
end

function ContractService:ListDeliveryLocations(callback)
    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if self.repository == nil then
        return callback_repository_missing(callback)
    end

    return self.repository:ListDeliveryLocations(callback)
end

function ContractService:GetDeliveryLocation(location_key, callback)
    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if self.repository == nil then
        return callback_repository_missing(callback)
    end

    return self.repository:GetDeliveryLocation(location_key, callback)
end

function ContractService:GetDeliveryLocationInfo(location_key, callback)
    local normalized_location_key = normalize_location_key(location_key)

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if self.repository == nil then
        return callback_repository_missing(callback)
    end

    if normalized_location_key == nil then
        callback(false, nil, "location-not-found")
        return true
    end

    return self.repository:GetDeliveryLocation(normalized_location_key, function(is_success, delivery_location, error)
        if not is_success then
            callback(false, nil, error or "database-error")
            return
        end

        if delivery_location == nil then
            callback(false, nil, "location-not-found")
            return
        end

        callback(true, delivery_location, nil)
    end)
end

function ContractService:SetDeliveryLocationHere(player, location_key, radius, callback)
    local normalized_location_key = normalize_location_key(location_key)
    local normalized_radius = nil

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if self.repository == nil then
        return callback_repository_missing(callback)
    end

    if normalized_location_key == nil then
        callback(false, nil, "location-not-found")
        return true
    end

    if radius ~= nil then
        normalized_radius = normalize_number(radius)

        if normalized_radius == nil or normalized_radius <= 0 or normalized_radius > MAX_DELIVERY_LOCATION_RADIUS then
            callback(false, nil, "invalid-radius")
            return true
        end
    end

    local controlled_character = get_controlled_character(player)

    if controlled_character == nil then
        callback(false, nil, "player-position-unavailable")
        return true
    end

    local player_location = get_entity_location(controlled_character)

    if player_location == nil then
        callback(false, nil, "player-position-unavailable")
        return true
    end

    return self.repository:GetDeliveryLocation(normalized_location_key, function(is_get_success, delivery_location, get_error)
        local effective_radius = normalized_radius

        if not is_get_success then
            callback(false, nil, get_error or "database-error")
            return
        end

        if delivery_location == nil then
            callback(false, nil, "location-not-found")
            return
        end

        if delivery_location.is_active ~= true then
            callback(false, nil, "location-inactive")
            return
        end

        if effective_radius == nil then
            effective_radius = normalize_number(delivery_location.radius) or DEFAULT_DELIVERY_LOCATION_RADIUS
        end

        if effective_radius <= 0 or effective_radius > MAX_DELIVERY_LOCATION_RADIUS then
            callback(false, nil, "invalid-radius")
            return
        end

        self.repository:UpdateDeliveryLocationPosition(
            normalized_location_key,
            player_location.x,
            player_location.y,
            player_location.z,
            effective_radius,
            function(is_update_success, updated_delivery_location, update_error)
                if not is_update_success then
                    callback(false, nil, update_error or "database-error")
                    return
                end

                if updated_delivery_location == nil then
                    callback(false, nil, "database-error")
                    return
                end

                callback(true, updated_delivery_location, nil)
            end
        )
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

function ContractService:ValidateDeliveryLocationProximity(player, delivery_location)
    if type(delivery_location) ~= "table" then
        return false, "delivery-location-not-found"
    end

    if delivery_location.is_active ~= true then
        return false, "delivery-location-inactive"
    end

    local position_x = normalize_number(delivery_location.position_x)
    local position_y = normalize_number(delivery_location.position_y)
    local position_z = normalize_number(delivery_location.position_z)
    local radius = normalize_number(delivery_location.radius)

    if position_x == nil or position_y == nil or position_z == nil or radius == nil or radius <= 0 then
        return false, "delivery-location-position-missing"
    end

    local controlled_character = get_controlled_character(player)

    if controlled_character == nil then
        return false, "player-position-unavailable"
    end

    local player_location = get_entity_location(controlled_character)

    if player_location == nil then
        return false, "player-position-unavailable"
    end

    local distance_squared = get_distance_squared(player_location, {
        x = position_x,
        y = position_y,
        z = position_z,
    })

    if distance_squared == nil then
        return false, "player-position-unavailable"
    end

    if distance_squared > (radius * radius) then
        return false, "too-far-from-delivery-location"
    end

    return true, nil
end

function ContractService:CompleteContract(character_id, contract_id, player_or_callback, callback)
    local normalized_character_id = normalize_positive_integer(character_id)
    local normalized_contract_id = normalize_contract_id(contract_id)
    local player = player_or_callback

    if type(player_or_callback) == "function" and callback == nil then
        callback = player_or_callback
        player = nil
    end

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

        if contract_row.status == "completed" then
            if normalize_payment_status(contract_row.payment_status) == "paid" then
                Console.Log(
                    "[gr_contracts][service] Contract payment skipped reason=already-paid contract_id=%s.",
                    tostring(normalized_contract_id)
                )
            end

            callback(false, nil, "contract-already-completed")
            return
        end

        if contract_row.status ~= "accepted"
            or normalize_positive_integer(contract_row.assignee_character_id) ~= normalized_character_id
        then
            callback(false, nil, "contract-complete-forbidden")
            return
        end

        local required_item_key = normalize_item_key(contract_row.required_item_key)
        local required_item_quantity = normalize_positive_integer(contract_row.required_item_quantity)
        local should_consume_required_items = contract_row.consume_required_items ~= false
        local inventory_bridge = nil
        local delivery_location_key = normalize_location_key(contract_row.delivery_location_key)
        local requires_delivery_location = contract_row.requires_delivery_location == true

        local function continue_after_requirements()
            self.repository:CompleteContract(normalized_contract_id, normalized_character_id, function(is_complete_success, completed_row, complete_error)
                if not is_complete_success then
                    if required_item_key ~= nil and required_item_quantity ~= nil and should_consume_required_items and inventory_bridge ~= nil then
                        inventory_bridge.AddItem(normalized_character_id, required_item_key, required_item_quantity, nil, function(is_compensation_success)
                            if not is_compensation_success then
                                callback(false, contract_row, "inventory-compensation-failed")
                                return
                            end

                            callback(false, contract_row, complete_error or "contract-complete-failed")
                        end)
                        return
                    end

                    callback(false, nil, complete_error)
                    return
                end

                if completed_row == nil then
                    if required_item_key ~= nil and required_item_quantity ~= nil and should_consume_required_items and inventory_bridge ~= nil then
                        inventory_bridge.AddItem(normalized_character_id, required_item_key, required_item_quantity, nil, function(is_compensation_success)
                            if not is_compensation_success then
                                callback(false, contract_row, "inventory-compensation-failed")
                                return
                            end

                            callback(false, contract_row, "contract-complete-forbidden")
                        end)
                        return
                    end

                    callback(false, nil, "contract-complete-forbidden")
                    return
                end

                local reward_money = normalize_reward_money(completed_row.reward_money) or 0

                local function finish_success(payment_status, money_result)
                    local enriched_row = {}

                    for key, value in pairs(completed_row) do
                        enriched_row[key] = value
                    end

                    enriched_row.payment_status = payment_status
                    enriched_row.money_result = money_result

                    Console.Log(
                        "[gr_contracts][service] Contract completed id=%s assignee_character_id=%s.",
                        tostring(enriched_row.id),
                        tostring(normalized_character_id)
                    )

                    callback(true, enriched_row, nil)
                end

                local function mark_payment_and_finish(payment_status, money_result)
                    self.repository:MarkContractPayment(normalized_contract_id, payment_status, function(is_mark_success, marked_row, mark_error)
                        if not is_mark_success then
                            Console.Log(
                                "[gr_contracts][service] Contract payment tracking failed contract_id=%s payment_status=%s reason=%s.",
                                tostring(normalized_contract_id),
                                tostring(payment_status),
                                tostring(mark_error)
                            )
                            finish_success(payment_status, money_result)
                            return
                        end

                        if marked_row ~= nil then
                            completed_row = marked_row
                        end

                        finish_success(payment_status, money_result)
                    end)
                end

                local function fail_with_payment_compensation(error_code)
                    if required_item_key == nil or required_item_quantity == nil or not should_consume_required_items or inventory_bridge == nil then
                        callback(false, completed_row, error_code)
                        return
                    end

                    inventory_bridge.AddItem(normalized_character_id, required_item_key, required_item_quantity, nil, function(is_compensation_success)
                        if not is_compensation_success then
                            Console.Log(
                                "[gr_contracts][service] Contract item compensation failed contract_id=%s assignee_character_id=%s item_key=%s quantity=%s.",
                                tostring(normalized_contract_id),
                                tostring(normalized_character_id),
                                tostring(required_item_key),
                                tostring(required_item_quantity)
                            )
                            callback(false, completed_row, "inventory-compensation-failed")
                            return
                        end

                        callback(false, completed_row, error_code)
                    end)
                end

                if reward_money <= 0 then
                    Console.Log(
                        "[gr_contracts][service] Contract payment unavailable reason=%s contract_id=%s.",
                        "reward-money-non-positive",
                        tostring(normalized_contract_id)
                    )
                    mark_payment_and_finish("unavailable", {
                        money_bank = nil,
                        amount = reward_money,
                    })
                    return
                end

                local economy_bridge = resolve_economy_bridge()

                if economy_bridge == nil then
                    Console.Log(
                        "[gr_contracts][service] Contract payment failed reason=%s contract_id=%s.",
                        "economy-bridge-unavailable",
                        tostring(normalized_contract_id)
                    )
                    self.repository:MarkContractPayment(normalized_contract_id, "failed", function()
                        fail_with_payment_compensation("payment-failed")
                    end)
                    return
                end

                local payment_reason = string.format("contract:%s", tostring(normalized_contract_id))
                local payment_metadata = {
                    contract_id = normalized_contract_id,
                    contract_type = completed_row.type,
                    source = "gr-contracts",
                    required_item_key = required_item_key,
                    required_item_quantity = required_item_quantity,
                }

                Console.Log(
                    "[gr_contracts][service] Contract payment requested through economy contract_id=%s assignee_character_id=%s amount=%s.",
                    tostring(normalized_contract_id),
                    tostring(normalized_character_id),
                    tostring(reward_money)
                )

                economy_bridge.AddMoney(
                    normalized_character_id,
                    "bank",
                    reward_money,
                    payment_reason,
                    payment_metadata,
                    function(is_credit_success, money_result, credit_error)
                        if not is_credit_success or money_result == nil then
                            Console.Log(
                                "[gr_contracts][service] Contract payment failed through economy contract_id=%s assignee_character_id=%s amount=%s reason=%s.",
                                tostring(normalized_contract_id),
                                tostring(normalized_character_id),
                                tostring(reward_money),
                                tostring(credit_error or "economy-credit-failed")
                            )

                            self.repository:MarkContractPayment(normalized_contract_id, "failed", function()
                                fail_with_payment_compensation("payment-failed")
                            end)
                            return
                        end

                        Console.Log(
                            "[gr_contracts][service] Contract payment completed through economy contract_id=%s assignee_character_id=%s amount=%s.",
                            tostring(normalized_contract_id),
                            tostring(normalized_character_id),
                            tostring(reward_money)
                        )

                        mark_payment_and_finish("paid", {
                            balance = money_result.balance,
                            transaction = money_result.transaction,
                            amount = reward_money,
                        })
                    end
                )
            end)
        end

        local function continue_after_delivery_location()
            if required_item_key == nil or required_item_quantity == nil or required_item_quantity < 1 or not should_consume_required_items then
                continue_after_requirements()
                return
            end

            inventory_bridge = resolve_inventory_bridge()

            if inventory_bridge == nil then
                callback(false, contract_row, "inventory-check-unavailable")
                return
            end

            inventory_bridge.ListInventory(normalized_character_id, function(is_list_success, inventory_rows, list_error)
                if not is_list_success then
                    Console.Log(
                        "[gr_contracts][service] Contract inventory check failed contract_id=%s assignee_character_id=%s reason=%s.",
                        tostring(normalized_contract_id),
                        tostring(normalized_character_id),
                        tostring(list_error or "inventory-list-failed")
                    )
                    callback(false, contract_row, "inventory-check-unavailable")
                    return
                end

                local has_items, available_quantity = has_required_items(inventory_rows, required_item_key, required_item_quantity)

                if not has_items then
                    local error_row = {}

                    for key, value in pairs(contract_row) do
                        error_row[key] = value
                    end

                    error_row.available_item_quantity = available_quantity
                    callback(false, error_row, "required-item-missing")
                    return
                end

                inventory_bridge.RemoveItem(normalized_character_id, required_item_key, required_item_quantity, function(is_remove_success, _, remove_error)
                    if not is_remove_success then
                        Console.Log(
                            "[gr_contracts][service] Contract inventory remove failed contract_id=%s assignee_character_id=%s item_key=%s quantity=%s reason=%s.",
                            tostring(normalized_contract_id),
                            tostring(normalized_character_id),
                            tostring(required_item_key),
                            tostring(required_item_quantity),
                            tostring(remove_error or "inventory-remove-failed")
                        )
                        callback(false, contract_row, "inventory-remove-failed")
                        return
                    end

                    continue_after_requirements()
                end)
            end)
        end

        if not requires_delivery_location then
            continue_after_delivery_location()
            return
        end

        if delivery_location_key == nil then
            callback(false, contract_row, "delivery-location-not-found")
            return
        end

        self.repository:GetDeliveryLocation(delivery_location_key, function(is_location_success, delivery_location, location_error)
            if not is_location_success then
                callback(false, contract_row, location_error or "delivery-location-not-found")
                return
            end

            if delivery_location == nil then
                callback(false, contract_row, "delivery-location-not-found")
                return
            end

            local is_near_delivery_location, proximity_error = self:ValidateDeliveryLocationProximity(player, delivery_location)

            if not is_near_delivery_location then
                callback(false, contract_row, proximity_error)
                return
            end

            continue_after_delivery_location()
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

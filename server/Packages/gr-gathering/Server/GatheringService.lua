GRGathering = GRGathering or {}
GRGathering.Server = GRGathering.Server or {}

local GatheringService = {}
GatheringService.__index = GatheringService

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

local function normalize_non_negative_integer(value)
    if type(value) == "number" then
        if value < 0 or value % 1 ~= 0 then
            return nil
        end

        return math.floor(value)
    end

    if type(value) == "string" and value:match("^%d+$") ~= nil then
        local parsed_value = tonumber(value)

        if parsed_value ~= nil then
            return math.floor(parsed_value)
        end
    end

    return nil
end

local function normalize_character_id(character_id)
    return normalize_positive_integer(character_id)
end

local function normalize_node_key(node_key)
    return trim_string(node_key)
end

local function normalize_skill_key(skill_key)
    local normalized_skill_key = trim_string(skill_key)

    if normalized_skill_key == nil then
        return nil
    end

    normalized_skill_key = string.lower(normalized_skill_key)

    if normalized_skill_key:match("^[a-z0-9_]+$") == nil then
        return nil
    end

    return normalized_skill_key
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

local function callback_repository_missing(callback)
    if type(callback) == "function" then
        callback(false, nil, "gathering-repository-missing")
    end

    return true
end

local function encode_metadata_json(metadata)
    if type(metadata) ~= "table" then
        return "{}"
    end

    local source = trim_string(metadata.source) or "gathering"
    local node_key = trim_string(metadata.node_key) or "unknown"

    return string.format(
        "{\"source\":\"%s\",\"node_key\":\"%s\"}",
        source,
        node_key
    )
end

local function build_inventory_quantity_map(inventory_rows)
    local quantity_by_item_key = {}

    for _, inventory_row in ipairs(inventory_rows or {}) do
        local item_key = trim_string(inventory_row.item_key)
        local quantity = normalize_positive_integer(inventory_row.quantity)

        if item_key ~= nil and quantity ~= nil then
            quantity_by_item_key[item_key] = (quantity_by_item_key[item_key] or 0) + quantity
        end
    end

    return quantity_by_item_key
end

local function build_skill_level_map(skill_rows)
    local level_by_skill_key = {}

    for _, skill_row in ipairs(skill_rows or {}) do
        local skill_key = normalize_skill_key(skill_row.skill_key)
        local level = normalize_positive_integer(skill_row.level) or 0

        if skill_key ~= nil then
            level_by_skill_key[skill_key] = level
        end
    end

    return level_by_skill_key
end

function GatheringService.Create(repository)
    local self = setmetatable({}, GatheringService)

    self.repository = repository

    return self
end

function GatheringService:ListNodes(callback)
    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if self.repository == nil then
        return callback_repository_missing(callback)
    end

    return self.repository:ListNodes(callback)
end

function GatheringService:GetNodeInfo(node_key, callback)
    local normalized_node_key = normalize_node_key(node_key)

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if self.repository == nil then
        return callback_repository_missing(callback)
    end

    if normalized_node_key == nil then
        callback(false, nil, "node-key-required")
        return true
    end

    return self.repository:GetNode(normalized_node_key, function(is_success, node_row, error)
        if not is_success then
            callback(false, nil, "database-error")
            return
        end

        if node_row == nil then
            callback(false, nil, "node-not-found")
            return
        end

        callback(true, node_row, nil)
    end)
end

function GatheringService:ValidateNodeProximity(player, node)
    local node_location = nil
    local player_location = nil
    local distance_squared = nil
    local radius_squared = nil

    if type(node) ~= "table" then
        return false, "node-not-found"
    end

    if node.requires_proximity ~= true then
        return true, nil
    end

    if type(node.position_x) ~= "number"
        or type(node.position_y) ~= "number"
        or type(node.position_z) ~= "number"
        or type(node.radius) ~= "number"
        or node.radius <= 0
    then
        return false, "node-position-invalid"
    end

    player_location = get_entity_location(get_controlled_character(player))

    if player_location == nil then
        return false, "player-position-unavailable"
    end

    node_location = {
        x = node.position_x,
        y = node.position_y,
        z = node.position_z,
    }

    distance_squared = get_distance_squared(player_location, node_location)

    if distance_squared == nil then
        return false, "player-position-unavailable"
    end

    radius_squared = node.radius * node.radius

    if distance_squared > radius_squared then
        return false, "too-far"
    end

    return true, nil
end

function GatheringService:ValidateGatheringRequirements(character_id, node, callback)
    local normalized_character_id = normalize_character_id(character_id)
    local required_item_key = nil
    local required_item_quantity = nil
    local required_skill_key = nil
    local required_skill_level = nil

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if normalized_character_id == nil then
        callback(false, nil, "invalid-character")
        return true
    end

    if type(node) ~= "table" then
        callback(false, nil, "node-not-found")
        return true
    end

    required_item_key = trim_string(node.required_item_key)
    required_item_quantity = normalize_positive_integer(node.required_item_quantity) or 1
    required_skill_key = normalize_skill_key(node.required_skill_key)
    required_skill_level = normalize_positive_integer(node.required_skill_level)

    local function validate_skill_requirement()
        if required_skill_key == nil or required_skill_level == nil then
            callback(true, nil, nil)
            return
        end

        if type(GRSkillsBridge) ~= "table" or type(GRSkillsBridge.ListSkills) ~= "function" then
            callback(false, {
                required_skill_key = required_skill_key,
                required_skill_level = required_skill_level,
            }, "skill-check-unavailable")
            return
        end

        GRSkillsBridge.ListSkills(normalized_character_id, function(is_success, skill_rows, error)
            local level_by_skill_key = nil
            local current_skill_level = 0

            if not is_success or type(skill_rows) ~= "table" then
                callback(false, {
                    required_skill_key = required_skill_key,
                    required_skill_level = required_skill_level,
                    skill_error = error,
                }, "skill-check-unavailable")
                return
            end

            level_by_skill_key = build_skill_level_map(skill_rows)
            current_skill_level = level_by_skill_key[required_skill_key] or 0

            if current_skill_level < required_skill_level then
                callback(false, {
                    required_skill_key = required_skill_key,
                    required_skill_level = required_skill_level,
                    current_skill_level = current_skill_level,
                }, "skill-level-insufficient")
                return
            end

            callback(true, nil, nil)
        end)
    end

    if required_item_key == nil then
        validate_skill_requirement()
        return true
    end

    if type(GRInventoryBridge) ~= "table" or type(GRInventoryBridge.ListInventory) ~= "function" then
        callback(false, {
            required_item_key = required_item_key,
            required_item_quantity = required_item_quantity,
        }, "inventory-check-unavailable")
        return true
    end

    GRInventoryBridge.ListInventory(normalized_character_id, function(is_success, inventory_rows, error)
        local quantity_by_item_key = nil
        local current_item_quantity = 0

        if not is_success or type(inventory_rows) ~= "table" then
            callback(false, {
                required_item_key = required_item_key,
                required_item_quantity = required_item_quantity,
                inventory_error = error,
            }, "inventory-check-unavailable")
            return
        end

        quantity_by_item_key = build_inventory_quantity_map(inventory_rows)
        current_item_quantity = quantity_by_item_key[required_item_key] or 0

        if current_item_quantity < required_item_quantity then
            callback(false, {
                required_item_key = required_item_key,
                required_item_quantity = required_item_quantity,
                current_item_quantity = current_item_quantity,
            }, "required-item-missing")
            return
        end

        validate_skill_requirement()
    end)

    return true
end

function GatheringService:Gather(character_id, player, node_key, callback)
    local normalized_character_id = normalize_character_id(character_id)
    local normalized_node_key = normalize_node_key(node_key)

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if self.repository == nil then
        return callback_repository_missing(callback)
    end

    if normalized_character_id == nil then
        callback(false, nil, "invalid-character")
        return true
    end

    if normalized_node_key == nil then
        callback(false, nil, "node-key-required")
        return true
    end

    return self.repository:GetNode(normalized_node_key, function(is_node_success, node_row, node_error)
        if not is_node_success then
            callback(false, nil, "database-error")
            return
        end

        if node_row == nil then
            callback(false, nil, "node-not-found")
            return
        end

        if node_row.is_active ~= true then
            callback(false, nil, "node-inactive")
            return
        end

        if node_row.result_item_key == nil
            or node_row.min_quantity == nil
            or node_row.max_quantity == nil
            or node_row.cooldown_seconds == nil
        then
            callback(false, nil, "database-error")
            return
        end

        local is_near_node, proximity_error = self:ValidateNodeProximity(player, node_row)

        if not is_near_node then
            callback(false, {
                node = node_row,
            }, proximity_error)
            return
        end

        self.repository:GetCooldown(normalized_character_id, normalized_node_key, function(is_cooldown_success, cooldown_row, cooldown_error)
            local current_epoch = os.time()
            local last_gathered_epoch = cooldown_row and cooldown_row.last_gathered_epoch or 0
            local remaining_seconds = 0

            if not is_cooldown_success then
                callback(false, nil, "database-error")
                return
            end

            if last_gathered_epoch > 0 then
                remaining_seconds = math.max(
                    0,
                    math.floor((last_gathered_epoch + node_row.cooldown_seconds) - current_epoch)
                )
            end

            if remaining_seconds > 0 then
                callback(false, {
                    node = node_row,
                    cooldown = cooldown_row,
                    remaining_seconds = remaining_seconds,
                }, "cooldown-active")
                return
            end

            self:ValidateGatheringRequirements(normalized_character_id, node_row, function(is_requirement_success, requirement_result, requirement_error)
                if not is_requirement_success then
                    callback(false, requirement_result, requirement_error)
                    return
                end

                if type(GRInventoryBridge) ~= "table" or type(GRInventoryBridge.AddItem) ~= "function" then
                    callback(false, {
                        node = node_row,
                    }, "inventory-unavailable")
                    return
                end

                if node_row.max_quantity < node_row.min_quantity then
                    callback(false, {
                        node = node_row,
                    }, "database-error")
                    return
                end

                local quantity = math.random(node_row.min_quantity, node_row.max_quantity)
                local metadata_json = encode_metadata_json({
                    source = "gathering",
                    node_key = normalized_node_key,
                })

                GRInventoryBridge.AddItem(
                    normalized_character_id,
                    node_row.result_item_key,
                    quantity,
                    metadata_json,
                    function(is_inventory_success, inventory_result, inventory_error)
                        if not is_inventory_success then
                            callback(false, {
                                node = node_row,
                                quantity = quantity,
                                inventory_error = inventory_error,
                            }, "inventory-failed")
                            return
                        end

                        self.repository:UpsertCooldown(normalized_character_id, normalized_node_key, function(is_upsert_success, updated_cooldown, upsert_error)
                            if not is_upsert_success or updated_cooldown == nil then
                                if type(GRInventoryBridge) ~= "table" or type(GRInventoryBridge.RemoveItem) ~= "function" then
                                    Console.Log(
                                        "[gr_gathering][service] Cooldown update failed without inventory rollback character_id=%s node_key=%s item_key=%s quantity=%s reason=%s.",
                                        tostring(normalized_character_id),
                                        tostring(normalized_node_key),
                                        tostring(node_row.result_item_key),
                                        tostring(quantity),
                                        tostring(upsert_error or "cooldown-upsert-failed")
                                    )

                                    callback(false, nil, "database-error")
                                    return
                                end

                                GRInventoryBridge.RemoveItem(
                                    normalized_character_id,
                                    node_row.result_item_key,
                                    quantity,
                                    function(is_rollback_success, rollback_result, rollback_error)
                                        if not is_rollback_success then
                                            Console.Log(
                                                "[gr_gathering][service] Inventory rollback failed character_id=%s node_key=%s item_key=%s quantity=%s reason=%s.",
                                                tostring(normalized_character_id),
                                                tostring(normalized_node_key),
                                                tostring(node_row.result_item_key),
                                                tostring(quantity),
                                                tostring(rollback_error or upsert_error or "rollback-failed")
                                            )
                                        end

                                        callback(false, {
                                            node = node_row,
                                            quantity = quantity,
                                            inventory = inventory_result,
                                            rollback = rollback_result,
                                        }, "database-error")
                                    end
                                )
                                return
                            end

                            local function finalize_success(skill_result, skill_error)
                                Console.Log(
                                    "[gr_gathering][service] Gathering completed character_id=%s node_key=%s item_key=%s quantity=%s.",
                                    tostring(normalized_character_id),
                                    tostring(normalized_node_key),
                                    tostring(node_row.result_item_key),
                                    tostring(quantity)
                                )

                                callback(true, {
                                    node = node_row,
                                    quantity = quantity,
                                    inventory = inventory_result,
                                    cooldown = updated_cooldown,
                                    skill = skill_result,
                                    skill_error = skill_error,
                                }, nil)
                            end

                            local normalized_skill_key = normalize_skill_key(node_row.required_skill_key)
                            local skill_xp = normalize_non_negative_integer(node_row.skill_xp) or 0

                            if normalized_skill_key == nil or skill_xp < 1 then
                                finalize_success(nil, nil)
                                return
                            end

                            if type(GRSkillsBridge) ~= "table" or type(GRSkillsBridge.AddSkillXp) ~= "function" then
                                Console.Log(
                                    "[gr_gathering][service] Skill XP skipped character_id=%s node_key=%s skill_key=%s reason=%s.",
                                    tostring(normalized_character_id),
                                    tostring(normalized_node_key),
                                    tostring(normalized_skill_key),
                                    "skills-bridge-unavailable"
                                )

                                finalize_success(nil, "skills-bridge-unavailable")
                                return
                            end

                            GRSkillsBridge.AddSkillXp(
                                normalized_character_id,
                                normalized_skill_key,
                                skill_xp,
                                "gather:" .. tostring(normalized_node_key),
                                function(is_skill_success, skill_row, skill_error)
                                    if not is_skill_success then
                                        Console.Log(
                                            "[gr_gathering][service] Skill XP grant failed character_id=%s node_key=%s skill_key=%s amount=%s reason=%s.",
                                            tostring(normalized_character_id),
                                            tostring(normalized_node_key),
                                            tostring(normalized_skill_key),
                                            tostring(skill_xp),
                                            tostring(skill_error or "skill-xp-failed")
                                        )

                                        finalize_success(nil, skill_error or "skill-xp-failed")
                                        return
                                    end

                                    finalize_success({
                                        skill_key = normalized_skill_key,
                                        amount = skill_xp,
                                        row = skill_row,
                                    }, nil)
                                end
                            )
                        end)
                    end
                )
            end)
        end)
    end)
end

GRGathering.Server.GatheringServiceClass = GatheringService

return GatheringService

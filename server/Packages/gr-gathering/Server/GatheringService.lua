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

local function normalize_stock_quantity(value)
    return normalize_non_negative_integer(value)
end

local function roll_chance_percent(chance_percent)
    local normalized_chance_percent = tonumber(chance_percent)

    if normalized_chance_percent == nil or normalized_chance_percent <= 0 then
        return false
    end

    if normalized_chance_percent >= 100 then
        return true
    end

    return math.random(1, 10000) <= math.floor((normalized_chance_percent * 100) + 0.5)
end

local function clone_reward_result(item_key, quantity, reward_type, chance_percent)
    return {
        item_key = item_key,
        quantity = quantity,
        reward_type = reward_type,
        chance_percent = chance_percent,
    }
end

local function build_reward_summary_text(reward_results)
    local parts = {}

    for _, reward_result in ipairs(reward_results or {}) do
        if trim_string(reward_result.item_key) ~= nil and normalize_positive_integer(reward_result.quantity) ~= nil then
            parts[#parts + 1] = string.format(
                "%s x%s",
                tostring(reward_result.item_key),
                tostring(reward_result.quantity)
            )
        end
    end

    return table.concat(parts, ", ")
end

local function build_node_info_payload(node_row, reward_rows)
    return {
        node = node_row,
        rewards = reward_rows or {},
        uses_legacy_rewards = type(reward_rows) ~= "table" or #reward_rows < 1,
    }
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

        self.repository:ListNodeRewards(normalized_node_key, function(is_rewards_success, reward_rows, reward_error)
            if not is_rewards_success then
                callback(false, nil, "database-error")
                return
            end

            callback(true, build_node_info_payload(node_row, reward_rows), nil)
        end)
    end)
end

function GatheringService:RestockNode(node_key, quantity, callback)
    local normalized_node_key = normalize_node_key(node_key)
    local normalized_quantity = nil

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

    if quantity ~= nil then
        normalized_quantity = normalize_positive_integer(quantity)

        if normalized_quantity == nil or normalized_quantity > 1000 then
            callback(false, nil, "quantity-required")
            return true
        end
    end

    return self.repository:RestockNode(normalized_node_key, normalized_quantity, callback)
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

function GatheringService:ResolveGatherQuantity(node)
    local quantity = nil
    local available_stock = nil

    if type(node) ~= "table" then
        return nil, "node-not-found"
    end

    if node.min_quantity == nil or node.max_quantity == nil or node.max_quantity < node.min_quantity then
        return nil, "database-error"
    end

    quantity = math.random(node.min_quantity, node.max_quantity)

    if node.stock_enabled ~= true then
        return quantity, nil
    end

    available_stock = normalize_stock_quantity(node.stock_quantity)

    if available_stock == nil then
        return nil, "stock-invalid"
    end

    if available_stock < 1 then
        return nil, "node-exhausted"
    end

    quantity = math.min(quantity, available_stock)

    if quantity < 1 then
        return nil, "node-exhausted"
    end

    return quantity, nil
end

function GatheringService:GenerateRewardResults(node, reward_rows)
    local generated_rewards = {}
    local primary_rewards = {}

    if type(node) ~= "table" then
        return nil, "node-not-found"
    end

    if type(reward_rows) ~= "table" or #reward_rows < 1 then
        local quantity, quantity_error = self:ResolveGatherQuantity(node)

        if quantity == nil then
            return nil, quantity_error or "database-error"
        end

        if trim_string(node.result_item_key) == nil then
            return nil, "database-error"
        end

        return {
            clone_reward_result(node.result_item_key, quantity, "legacy", 100),
        }, nil
    end

    for _, reward_row in ipairs(reward_rows) do
        if reward_row.reward_type == "primary" then
            primary_rewards[#primary_rewards + 1] = reward_row
        end

        if roll_chance_percent(reward_row.chance_percent) then
            generated_rewards[#generated_rewards + 1] = clone_reward_result(
                reward_row.item_key,
                math.random(reward_row.min_quantity, reward_row.max_quantity),
                reward_row.reward_type,
                reward_row.chance_percent
            )
        end
    end

    if #generated_rewards < 1 and #primary_rewards > 0 then
        generated_rewards[1] = clone_reward_result(
            primary_rewards[1].item_key,
            math.random(primary_rewards[1].min_quantity, primary_rewards[1].max_quantity),
            primary_rewards[1].reward_type,
            primary_rewards[1].chance_percent
        )
    end

    if #generated_rewards < 1 then
        return nil, "no-reward-generated"
    end

    return generated_rewards, nil
end

function GatheringService:CollapseRewardResults(reward_results)
    local collapsed_rewards = {}
    local reward_by_item_key = {}

    for _, reward_result in ipairs(reward_results or {}) do
        local item_key = trim_string(reward_result.item_key)
        local quantity = normalize_positive_integer(reward_result.quantity)

        if item_key ~= nil and quantity ~= nil then
            if reward_by_item_key[item_key] == nil then
                reward_by_item_key[item_key] = clone_reward_result(
                    item_key,
                    quantity,
                    reward_result.reward_type,
                    reward_result.chance_percent
                )
                collapsed_rewards[#collapsed_rewards + 1] = reward_by_item_key[item_key]
            else
                reward_by_item_key[item_key].quantity = reward_by_item_key[item_key].quantity + quantity
            end
        end
    end

    return collapsed_rewards
end

function GatheringService:ApplyStockLimit(node, reward_results)
    local total_quantity = 0
    local available_stock = nil

    if type(node) ~= "table" then
        return nil, nil, "node-not-found"
    end

    for _, reward_result in ipairs(reward_results or {}) do
        total_quantity = total_quantity + (normalize_positive_integer(reward_result.quantity) or 0)
    end

    if total_quantity < 1 then
        return nil, nil, "no-reward-generated"
    end

    if node.stock_enabled ~= true then
        return reward_results, total_quantity, nil
    end

    available_stock = normalize_stock_quantity(node.stock_quantity)

    if available_stock == nil then
        return nil, nil, "stock-invalid"
    end

    if available_stock < 1 then
        return nil, nil, "node-exhausted"
    end

    if total_quantity > available_stock then
        local quantity_to_trim = total_quantity - available_stock

        for reward_index = #reward_results, 1, -1 do
            local reward_result = reward_results[reward_index]
            local quantity = normalize_positive_integer(reward_result.quantity)

            if quantity ~= nil and quantity_to_trim > 0 then
                local reduction = math.min(quantity, quantity_to_trim)

                quantity = quantity - reduction
                quantity_to_trim = quantity_to_trim - reduction

                if quantity < 1 then
                    table.remove(reward_results, reward_index)
                else
                    reward_result.quantity = quantity
                end
            end
        end
    end

    total_quantity = 0

    for _, reward_result in ipairs(reward_results or {}) do
        total_quantity = total_quantity + (normalize_positive_integer(reward_result.quantity) or 0)
    end

    if total_quantity < 1 then
        return nil, nil, "node-exhausted"
    end

    return reward_results, total_quantity, nil
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

        self.repository:MaybeRestockNode(normalized_node_key, function(is_restock_success, maybe_restocked_node, restock_error)
            local current_epoch = os.time()
            local last_gathered_epoch = 0
            local remaining_seconds = 0
            local effective_node = maybe_restocked_node or node_row

            if not is_restock_success or type(effective_node) ~= "table" then
                callback(false, nil, "database-error")
                return
            end

            if effective_node.cooldown_seconds == nil then
                callback(false, nil, "database-error")
                return
            end

            local is_near_node, proximity_error = self:ValidateNodeProximity(player, effective_node)

            if not is_near_node then
                callback(false, {
                    node = effective_node,
                }, proximity_error)
                return
            end

            self.repository:GetCooldown(normalized_character_id, normalized_node_key, function(is_cooldown_success, cooldown_row, cooldown_error)
                if not is_cooldown_success then
                    callback(false, nil, "database-error")
                    return
                end

                last_gathered_epoch = cooldown_row and cooldown_row.last_gathered_epoch or 0

                if last_gathered_epoch > 0 then
                    remaining_seconds = math.max(
                        0,
                        math.floor((last_gathered_epoch + effective_node.cooldown_seconds) - current_epoch)
                    )
                end

                if remaining_seconds > 0 then
                    callback(false, {
                        node = effective_node,
                        cooldown = cooldown_row,
                        remaining_seconds = remaining_seconds,
                    }, "cooldown-active")
                    return
                end

                self:ValidateGatheringRequirements(normalized_character_id, effective_node, function(is_requirement_success, requirement_result, requirement_error)
                    if not is_requirement_success then
                        callback(false, requirement_result, requirement_error)
                        return
                    end

                    if type(GRInventoryBridge) ~= "table" or type(GRInventoryBridge.AddItem) ~= "function" then
                        callback(false, {
                            node = effective_node,
                        }, "inventory-unavailable")
                        return
                    end

                    self.repository:ListNodeRewards(normalized_node_key, function(is_rewards_success, reward_rows, rewards_error)
                        local generated_rewards = nil
                        local consumed_quantity = 0
                        local metadata_json = nil

                        if not is_rewards_success then
                            callback(false, {
                                node = effective_node,
                            }, "database-error")
                            return
                        end

                        generated_rewards, rewards_error = self:GenerateRewardResults(effective_node, reward_rows)

                        if generated_rewards == nil then
                            callback(false, {
                                node = effective_node,
                                rewards = reward_rows,
                            }, rewards_error or "database-error")
                            return
                        end

                        generated_rewards = self:CollapseRewardResults(generated_rewards)
                        generated_rewards, consumed_quantity, rewards_error = self:ApplyStockLimit(effective_node, generated_rewards)

                        if generated_rewards == nil or consumed_quantity == nil then
                            callback(false, {
                                node = effective_node,
                                rewards = reward_rows,
                            }, rewards_error or "database-error")
                            return
                        end

                        metadata_json = encode_metadata_json({
                            source = "gathering",
                            node_key = normalized_node_key,
                        })

                        local function rollback_stock(stock_source_node, final_error, rollback_reason, failure_context)
                            local base_context = failure_context or {}

                            base_context.node = stock_source_node or effective_node
                            base_context.rewards = generated_rewards
                            base_context.quantity = consumed_quantity

                            if effective_node.stock_enabled ~= true then
                                callback(false, base_context, final_error)
                                return
                            end

                            self.repository:IncreaseNodeStock(normalized_node_key, consumed_quantity, function(is_restore_success, restored_node, restore_error)
                                if not is_restore_success then
                                    Console.Log(
                                        "[gr_gathering][service] Stock rollback failed node_key=%s quantity=%s reason=%s.",
                                        tostring(normalized_node_key),
                                        tostring(consumed_quantity),
                                        tostring(restore_error or rollback_reason or "stock-compensation-failed")
                                    )

                                    base_context.rollback_error = restore_error
                                    callback(false, base_context, "stock-compensation-failed")
                                    return
                                end

                                base_context.node = restored_node
                                callback(false, base_context, final_error)
                            end)
                        end

                        local function rollback_inventory_rewards(added_rewards, stock_source_node, final_error, rollback_reason, failure_context)
                            local added_reward_count = type(added_rewards) == "table" and #added_rewards or 0

                            if added_reward_count < 1 then
                                rollback_stock(stock_source_node, final_error, rollback_reason, failure_context)
                                return
                            end

                            if type(GRInventoryBridge) ~= "table" or type(GRInventoryBridge.RemoveItem) ~= "function" then
                                local rollback_context = failure_context or {}

                                rollback_context.inventory_rollback_error = "inventory-rollback-unavailable"
                                rollback_stock(stock_source_node, final_error, rollback_reason, rollback_context)
                                return
                            end

                            local rollback_index = added_reward_count

                            local function rollback_next()
                                local reward_result = added_rewards[rollback_index]

                                if reward_result == nil then
                                    rollback_stock(stock_source_node, final_error, rollback_reason, failure_context)
                                    return
                                end

                                GRInventoryBridge.RemoveItem(
                                    normalized_character_id,
                                    reward_result.item_key,
                                    reward_result.quantity,
                                    function(is_rollback_success, rollback_result, rollback_error)
                                        if not is_rollback_success then
                                            local rollback_context = failure_context or {}

                                            rollback_context.inventory_rollback_error = rollback_error or "inventory-rollback-failed"

                                            Console.Log(
                                                "[gr_gathering][service] Inventory rollback failed character_id=%s node_key=%s item_key=%s quantity=%s reason=%s.",
                                                tostring(normalized_character_id),
                                                tostring(normalized_node_key),
                                                tostring(reward_result.item_key),
                                                tostring(reward_result.quantity),
                                                tostring(rollback_context.inventory_rollback_error)
                                            )

                                            rollback_stock(stock_source_node, final_error, rollback_reason, rollback_context)
                                            return
                                        end

                                        rollback_index = rollback_index - 1
                                        rollback_next()
                                    end
                                )
                            end

                            rollback_next()
                        end

                        local function add_inventory_rewards(stock_result)
                            local added_rewards = {}
                            local reward_index = 1

                            local function finalize_after_inventory()
                                self.repository:UpsertCooldown(normalized_character_id, normalized_node_key, function(is_upsert_success, updated_cooldown, upsert_error)
                                    local function finalize_success(skill_result, skill_error)
                                        Console.Log(
                                            "[gr_gathering][service] Gathering completed character_id=%s node_key=%s rewards=%s.",
                                            tostring(normalized_character_id),
                                            tostring(normalized_node_key),
                                            tostring(build_reward_summary_text(generated_rewards))
                                        )

                                        callback(true, {
                                            node = stock_result or effective_node,
                                            rewards = generated_rewards,
                                            quantity = consumed_quantity,
                                            inventory = added_rewards,
                                            cooldown = updated_cooldown,
                                            skill = skill_result,
                                            skill_error = skill_error,
                                        }, nil)
                                    end

                                    if not is_upsert_success or updated_cooldown == nil then
                                        rollback_inventory_rewards(
                                            added_rewards,
                                            stock_result,
                                            "database-error",
                                            "cooldown-upsert-failed",
                                            {
                                                upsert_error = upsert_error,
                                            }
                                        )
                                        return
                                    end

                                    local normalized_skill_key = normalize_skill_key(effective_node.required_skill_key)
                                    local skill_xp = normalize_non_negative_integer(effective_node.skill_xp) or 0

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

                            local function add_next_reward()
                                local reward_result = generated_rewards[reward_index]

                                if reward_result == nil then
                                    finalize_after_inventory()
                                    return
                                end

                                GRInventoryBridge.AddItem(
                                    normalized_character_id,
                                    reward_result.item_key,
                                    reward_result.quantity,
                                    metadata_json,
                                    function(is_inventory_success, inventory_result, inventory_error)
                                        if not is_inventory_success then
                                            rollback_inventory_rewards(
                                                added_rewards,
                                                stock_result,
                                                "inventory-failed",
                                                "inventory-add-failed",
                                                {
                                                    inventory_error = inventory_error,
                                                    failed_reward = reward_result,
                                                }
                                            )
                                            return
                                        end

                                        added_rewards[#added_rewards + 1] = {
                                            item_key = reward_result.item_key,
                                            quantity = reward_result.quantity,
                                            inventory = inventory_result,
                                        }

                                        reward_index = reward_index + 1
                                        add_next_reward()
                                    end
                                )
                            end

                            add_next_reward()
                        end

                        if effective_node.stock_enabled == true then
                            self.repository:DecreaseNodeStock(normalized_node_key, consumed_quantity, function(is_stock_success, stock_result, stock_error)
                                if not is_stock_success or stock_result == nil then
                                    callback(false, {
                                        node = effective_node,
                                        rewards = generated_rewards,
                                        quantity = consumed_quantity,
                                    }, stock_error or "stock-update-failed")
                                    return
                                end

                                add_inventory_rewards(stock_result)
                            end)
                            return
                        end

                        add_inventory_rewards(effective_node)
                    end)
                end)
            end)
        end)
    end)
end

GRGathering.Server.GatheringServiceClass = GatheringService

return GatheringService

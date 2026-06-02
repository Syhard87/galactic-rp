GRCrafting = GRCrafting or {}
GRCrafting.Server = GRCrafting.Server or {}

local CraftingService = {}
CraftingService.__index = CraftingService

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

        if parsed_value ~= nil and parsed_value >= 0 then
            return math.floor(parsed_value)
        end
    end

    return nil
end

local function normalize_recipe_key(recipe_key)
    local normalized_recipe_key = trim_string(recipe_key)

    if normalized_recipe_key == nil then
        return nil
    end

    return string.lower(normalized_recipe_key)
end

local function normalize_skill_key(skill_key)
    local normalized_skill_key = trim_string(skill_key)

    if normalized_skill_key == nil then
        return nil
    end

    return string.lower(normalized_skill_key)
end

local function normalize_station_key(station_key)
    local normalized_station_key = trim_string(station_key)

    if normalized_station_key == nil then
        return nil
    end

    return string.lower(normalized_station_key)
end

local function get_platform_id(player)
    if type(player) ~= "table" and type(player) ~= "userdata" then
        return nil
    end

    if type(player.GetAccountID) ~= "function" then
        return nil
    end

    return player:GetAccountID()
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

    return location
end

local function get_player_location(player)
    return get_entity_location(get_controlled_character(player))
end

local function get_distance_squared(first_location, second_location)
    if first_location == nil or second_location == nil then
        return nil
    end

    local delta_x = first_location.X - second_location.X
    local delta_y = first_location.Y - second_location.Y
    local delta_z = first_location.Z - second_location.Z

    return (delta_x * delta_x) + (delta_y * delta_y) + (delta_z * delta_z)
end

local function find_player_by_active_character_id(character_id)
    local normalized_character_id = normalize_positive_integer(character_id)

    if normalized_character_id == nil then
        return nil
    end

    if type(Player) ~= "table" or type(Player.GetAll) ~= "function" then
        return nil
    end

    if type(GRCharactersBridge) ~= "table" or type(GRCharactersBridge.GetActiveCharacter) ~= "function" then
        return nil
    end

    for _, candidate_player in pairs(Player.GetAll()) do
        local platform_id = get_platform_id(candidate_player)
        local active_character = nil

        if platform_id ~= nil then
            active_character = GRCharactersBridge.GetActiveCharacter(platform_id)
        end

        if type(active_character) == "table" and normalize_positive_integer(active_character.id) == normalized_character_id then
            return candidate_player
        end
    end

    return nil
end

local function resolve_active_character_id(player_or_platform_id)
    local active_character = nil

    if type(GRCharactersBridge) ~= "table" or type(GRCharactersBridge.GetActiveCharacter) ~= "function" then
        return nil, "characters-bridge-unavailable"
    end

    active_character = GRCharactersBridge.GetActiveCharacter(player_or_platform_id)

    if type(active_character) ~= "table" or active_character.id == nil then
        return nil, "active-character-missing"
    end

    return normalize_positive_integer(active_character.id), nil
end

local function callback_repository_missing(callback)
    if type(callback) == "function" then
        callback(false, nil, "crafting-repository-missing")
    end

    return true
end

local function aggregate_inventory_by_item_key(inventory_rows)
    local quantities = {}

    for _, inventory_row in ipairs(inventory_rows or {}) do
        local item_key = inventory_row.item_key
        local quantity = normalize_positive_integer(inventory_row.quantity) or 0

        if item_key ~= nil then
            quantities[item_key] = (quantities[item_key] or 0) + quantity
        end
    end

    return quantities
end

function CraftingService.Create(repository)
    local self = setmetatable({}, CraftingService)

    self.repository = repository

    return self
end

function CraftingService:ListActiveStations(callback)
    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if self.repository == nil then
        return callback_repository_missing(callback)
    end

    return self.repository:ListActiveStations(callback)
end

function CraftingService:CraftItemForActiveCharacter(player_or_platform_id, recipe_key, callback)
    local active_character_id = nil
    local resolve_error = nil

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if self.repository == nil then
        return callback_repository_missing(callback)
    end

    active_character_id, resolve_error = resolve_active_character_id(player_or_platform_id)

    if active_character_id == nil then
        callback(false, nil, resolve_error)
        return true
    end

    return self:CraftItem(active_character_id, recipe_key, callback, player_or_platform_id)
end

function CraftingService:ListActiveRecipes(callback)
    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if self.repository == nil then
        return callback_repository_missing(callback)
    end

    return self.repository:ListActiveRecipes(callback)
end

function CraftingService:CraftItem(character_id, recipe_key, callback, player_or_platform_id)
    local normalized_character_id = normalize_positive_integer(character_id)
    local normalized_recipe_key = normalize_recipe_key(recipe_key)

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

    if normalized_recipe_key == nil then
        callback(false, nil, "recipe-key-required")
        return true
    end

    return self.repository:GetRecipeByKey(normalized_recipe_key, function(is_recipe_success, recipe_row, recipe_error)
        if not is_recipe_success then
            callback(false, nil, recipe_error)
            return
        end

        if recipe_row == nil or recipe_row.is_active ~= true then
            callback(false, nil, "recipe-not-found")
            return
        end

        local function check_required_station_then_continue(on_success)
            local required_station_key = normalize_station_key(recipe_row.station_key)

            if required_station_key == nil then
                on_success()
                return
            end

            self.repository:GetStationByKey(required_station_key, function(is_station_success, station_row, station_error)
                local player = nil
                local player_location = nil
                local station_location = nil
                local distance_squared = nil
                local station_radius_squared = nil

                if not is_station_success then
                    callback(false, nil, station_error)
                    return
                end

                if station_row == nil then
                    callback(false, nil, "required-station-not-found")
                    return
                end

                if station_row.is_active ~= true then
                    callback(false, nil, "required-station-inactive")
                    return
                end

                if player_or_platform_id ~= nil and get_platform_id(player_or_platform_id) ~= nil then
                    player = player_or_platform_id
                else
                    player = find_player_by_active_character_id(normalized_character_id)
                end

                if player == nil then
                    callback(false, nil, "station-player-location-unavailable")
                    return
                end

                player_location = get_player_location(player)

                if player_location == nil then
                    callback(false, nil, "station-player-location-unavailable")
                    return
                end

                station_location = {
                    X = station_row.position_x,
                    Y = station_row.position_y,
                    Z = station_row.position_z,
                }

                distance_squared = get_distance_squared(player_location, station_location)
                station_radius_squared = station_row.radius * station_row.radius

                if distance_squared == nil then
                    callback(false, nil, "station-distance-unavailable")
                    return
                end

                if distance_squared > station_radius_squared then
                    callback(false, nil, "required-station-too-far")
                    return
                end

                on_success()
            end)
        end

        self.repository:ListIngredientsByRecipeKey(normalized_recipe_key, function(is_ingredients_success, ingredient_rows, ingredients_error)
            local function finish_with_skill_reward(result)
                local craft_xp_skill_key = normalize_skill_key(recipe_row.craft_xp_skill_key)
                local craft_xp_amount = normalize_positive_integer(recipe_row.craft_xp_amount)

                if craft_xp_skill_key == nil or craft_xp_amount == nil then
                    Console.Log(
                        "[gr_crafting][service] Craft has no skill reward recipe_key=%s.",
                        tostring(recipe_row.key)
                    )
                    callback(true, result, nil)
                    return
                end

                if type(GRSkillsBridge) ~= "table" or type(GRSkillsBridge.AddSkillXp) ~= "function" then
                    Console.Log(
                        "[gr_crafting][service] Craft skill reward skipped reason=skills-bridge-unavailable recipe_key=%s.",
                        tostring(recipe_row.key)
                    )
                    callback(true, result, nil)
                    return
                end

                GRSkillsBridge.AddSkillXp(
                    normalized_character_id,
                    craft_xp_skill_key,
                    craft_xp_amount,
                    string.format("craft:%s", tostring(recipe_row.key)),
                    function(is_skill_success, _, skill_error)
                        if not is_skill_success then
                            Console.Log(
                                "[gr_crafting][service] Craft skill reward failed character_id=%s recipe_key=%s skill_key=%s reason=%s.",
                                tostring(normalized_character_id),
                                tostring(recipe_row.key),
                                tostring(craft_xp_skill_key),
                                tostring(skill_error)
                            )
                            callback(true, result, nil)
                            return
                        end

                        result.reward_skill_key = craft_xp_skill_key
                        result.reward_skill_xp = craft_xp_amount

                        Console.Log(
                            "[gr_crafting][service] Craft skill reward granted character_id=%s recipe_key=%s skill_key=%s amount=%s.",
                            tostring(normalized_character_id),
                            tostring(recipe_row.key),
                            tostring(craft_xp_skill_key),
                            tostring(craft_xp_amount)
                        )

                        callback(true, result, nil)
                    end
                )
            end

            local function check_required_skill_then_continue(on_success)
                local required_skill_key = normalize_skill_key(recipe_row.required_skill_key)
                local required_skill_level = normalize_non_negative_integer(recipe_row.required_skill_level) or 0

                if required_skill_key == nil or required_skill_level < 1 then
                    on_success()
                    return
                end

                if type(GRSkillsBridge) ~= "table" or type(GRSkillsBridge.ListSkills) ~= "function" then
                    callback(false, nil, "required-skill-service-unavailable")
                    return
                end

                GRSkillsBridge.ListSkills(normalized_character_id, function(is_skills_success, skill_rows, skills_error)
                    local current_skill_level = 0

                    if not is_skills_success then
                        callback(false, nil, skills_error)
                        return
                    end

                    for _, skill_row in ipairs(skill_rows or {}) do
                        if normalize_skill_key(skill_row.skill_key) == required_skill_key then
                            current_skill_level = normalize_non_negative_integer(skill_row.level) or 0
                            break
                        end
                    end

                    if current_skill_level < required_skill_level then
                        callback(false, nil, "required-skill-level-insufficient")
                        return
                    end

                    on_success()
                end)
            end

            if not is_ingredients_success then
                callback(false, nil, ingredients_error)
                return
            end

            ingredient_rows = ingredient_rows or {}

            if ingredient_rows[1] == nil then
                callback(false, nil, "recipe-ingredients-missing")
                return
            end

            check_required_station_then_continue(function()
                check_required_skill_then_continue(function()
                    local removed_ingredients = {}
                    local inventory_totals = nil

                    if type(GRInventoryBridge) ~= "table"
                        or type(GRInventoryBridge.ListInventory) ~= "function"
                        or type(GRInventoryBridge.RemoveItem) ~= "function"
                        or type(GRInventoryBridge.AddItem) ~= "function"
                    then
                        callback(false, nil, "inventory-bridge-unavailable")
                        return
                    end

                    local function restore_removed_ingredients(reason, done_callback)
                        local restore_index = 1

                        if removed_ingredients[1] == nil then
                            done_callback()
                            return
                        end

                        Console.Log(
                            "[gr_crafting][service] Craft rollback started character_id=%s recipe_key=%s reason=%s count=%s.",
                            tostring(normalized_character_id),
                            tostring(recipe_row.key),
                            tostring(reason),
                            tostring(#removed_ingredients)
                        )

                        local function restore_next()
                            local removed_ingredient = removed_ingredients[restore_index]

                            if removed_ingredient == nil then
                                Console.Log(
                                    "[gr_crafting][service] Craft rollback completed character_id=%s recipe_key=%s.",
                                    tostring(normalized_character_id),
                                    tostring(recipe_row.key)
                                )
                                done_callback()
                                return
                            end

                            GRInventoryBridge.AddItem(
                                normalized_character_id,
                                removed_ingredient.item_key,
                                removed_ingredient.quantity,
                                nil,
                                function(is_restore_success, _, restore_error)
                                    if not is_restore_success then
                                        Console.Log(
                                            "[gr_crafting][service] Craft rollback failed character_id=%s recipe_key=%s item_key=%s quantity=%s reason=%s.",
                                            tostring(normalized_character_id),
                                            tostring(recipe_row.key),
                                            tostring(removed_ingredient.item_key),
                                            tostring(removed_ingredient.quantity),
                                            tostring(restore_error)
                                        )
                                        done_callback()
                                        return
                                    end

                                    restore_index = restore_index + 1
                                    restore_next()
                                end
                            )
                        end

                        restore_next()
                    end

                    local function add_crafted_item()
                        local result = {
                            recipe_key = recipe_row.key,
                            result_item_key = recipe_row.result_item_key,
                            result_quantity = recipe_row.result_quantity,
                            removed_ingredients = removed_ingredients,
                            reward_skill_key = nil,
                            reward_skill_xp = 0,
                        }

                        GRInventoryBridge.AddItem(
                            normalized_character_id,
                            recipe_row.result_item_key,
                            recipe_row.result_quantity,
                            nil,
                            function(is_add_success, _, add_error)
                                if not is_add_success then
                                    Console.Log(
                                        "[gr_crafting][service] Craft result add failed character_id=%s recipe_key=%s item_key=%s quantity=%s reason=%s.",
                                        tostring(normalized_character_id),
                                        tostring(recipe_row.key),
                                        tostring(recipe_row.result_item_key),
                                        tostring(recipe_row.result_quantity),
                                        tostring(add_error)
                                    )

                                    restore_removed_ingredients("result-add-failed", function()
                                        callback(false, nil, "craft-result-add-failed")
                                    end)
                                    return
                                end

                                Console.Log(
                                    "[gr_crafting][service] Craft result added character_id=%s recipe_key=%s item_key=%s quantity=%s.",
                                    tostring(normalized_character_id),
                                    tostring(recipe_row.key),
                                    tostring(recipe_row.result_item_key),
                                    tostring(recipe_row.result_quantity)
                                )

                                finish_with_skill_reward(result)
                            end
                        )
                    end

                    local function remove_next_ingredient(index)
                        local ingredient_row = ingredient_rows[index]

                        if ingredient_row == nil then
                            add_crafted_item()
                            return
                        end

                        GRInventoryBridge.RemoveItem(
                            normalized_character_id,
                            ingredient_row.item_key,
                            ingredient_row.quantity,
                            function(is_remove_success, _, remove_error)
                                if not is_remove_success then
                                    Console.Log(
                                        "[gr_crafting][service] Craft ingredient removal failed character_id=%s recipe_key=%s item_key=%s quantity=%s reason=%s.",
                                        tostring(normalized_character_id),
                                        tostring(recipe_row.key),
                                        tostring(ingredient_row.item_key),
                                        tostring(ingredient_row.quantity),
                                        tostring(remove_error)
                                    )

                                    restore_removed_ingredients("ingredient-remove-failed", function()
                                        callback(false, nil, remove_error or "ingredient-remove-failed")
                                    end)
                                    return
                                end

                                removed_ingredients[#removed_ingredients + 1] = {
                                    item_key = ingredient_row.item_key,
                                    quantity = ingredient_row.quantity,
                                }

                                remove_next_ingredient(index + 1)
                            end
                        )
                    end

                    GRInventoryBridge.ListInventory(normalized_character_id, function(is_inventory_success, inventory_rows, inventory_error)
                        if not is_inventory_success then
                            callback(false, nil, inventory_error)
                            return
                        end

                        inventory_totals = aggregate_inventory_by_item_key(inventory_rows)

                        for _, ingredient_row in ipairs(ingredient_rows) do
                            if (inventory_totals[ingredient_row.item_key] or 0) < ingredient_row.quantity then
                                callback(false, nil, "ingredients-insufficient")
                                return
                            end
                        end

                        remove_next_ingredient(1)
                    end)
                end)
            end)
        end)
    end)
end

GRCrafting.Server.CraftingServiceClass = CraftingService

return CraftingService

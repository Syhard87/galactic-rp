GRCrafting = GRCrafting or {}
GRCrafting.Server = GRCrafting.Server or {}

local CraftingRepository = {}
CraftingRepository.__index = CraftingRepository

local SELECT_ACTIVE_RECIPES_QUERY = [[
    SELECT
        key,
        category,
        result_item_key,
        result_quantity,
        required_skill_key,
        required_skill_level,
        craft_xp_skill_key,
        craft_xp_amount,
        station_key,
        duration_seconds,
        is_active,
        created_at,
        updated_at
    FROM crafting_recipes
    WHERE is_active = TRUE
    ORDER BY key ASC
]]

local SELECT_RECIPE_BY_KEY_QUERY = [[
    SELECT
        key,
        category,
        result_item_key,
        result_quantity,
        required_skill_key,
        required_skill_level,
        craft_xp_skill_key,
        craft_xp_amount,
        station_key,
        duration_seconds,
        is_active,
        created_at,
        updated_at
    FROM crafting_recipes
    WHERE key = :0
    LIMIT 1
]]

local SELECT_INGREDIENTS_BY_RECIPE_KEY_QUERY = [[
    SELECT
        id,
        recipe_key,
        item_key,
        quantity,
        created_at
    FROM crafting_recipe_ingredients
    WHERE recipe_key = :0
    ORDER BY item_key ASC, id ASC
]]

local SELECT_STATION_BY_KEY_QUERY = [[
    SELECT
        key,
        name,
        station_type,
        position_x,
        position_y,
        position_z,
        radius,
        is_active,
        created_at,
        updated_at
    FROM crafting_stations
    WHERE key = :0
    LIMIT 1
]]

local SELECT_ACTIVE_STATIONS_QUERY = [[
    SELECT
        key,
        name,
        station_type,
        position_x,
        position_y,
        position_z,
        radius,
        is_active,
        created_at,
        updated_at
    FROM crafting_stations
    WHERE is_active = TRUE
    ORDER BY key ASC
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
        if value < 0 then
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

local function normalize_item_key(item_key)
    local normalized_item_key = trim_string(item_key)

    if normalized_item_key == nil then
        return nil
    end

    return string.lower(normalized_item_key)
end

local function normalize_station_key(station_key)
    local normalized_station_key = trim_string(station_key)

    if normalized_station_key == nil then
        return nil
    end

    return string.lower(normalized_station_key)
end

local function normalize_boolean(value, fallback)
    if type(value) == "boolean" then
        return value
    end

    if type(value) == "number" then
        if value == 1 then
            return true
        end

        if value == 0 then
            return false
        end
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

local function normalize_coordinate(value)
    if type(value) == "number" then
        return value
    end

    if type(value) == "string" then
        local parsed_value = tonumber(value)

        if parsed_value ~= nil then
            return parsed_value
        end
    end

    return nil
end

local function normalize_positive_coordinate(value)
    local normalized_value = normalize_coordinate(value)

    if normalized_value == nil or normalized_value <= 0 then
        return nil
    end

    return normalized_value
end

local function normalize_recipe_row(row)
    local recipe_key = nil
    local result_item_key = nil

    if type(row) ~= "table" then
        return nil
    end

    recipe_key = normalize_recipe_key(row.key)
    result_item_key = normalize_item_key(row.result_item_key)

    if recipe_key == nil or result_item_key == nil then
        return nil
    end

    return {
        key = recipe_key,
        category = trim_string(row.category) or "utility",
        result_item_key = result_item_key,
        result_quantity = normalize_positive_integer(row.result_quantity),
        required_skill_key = normalize_skill_key(row.required_skill_key),
        required_skill_level = normalize_non_negative_integer(row.required_skill_level, 0),
        craft_xp_skill_key = normalize_skill_key(row.craft_xp_skill_key),
        craft_xp_amount = normalize_non_negative_integer(row.craft_xp_amount, 0),
        station_key = normalize_station_key(row.station_key),
        duration_seconds = normalize_non_negative_integer(row.duration_seconds, 0),
        is_active = normalize_boolean(row.is_active, false),
        created_at = row.created_at,
        updated_at = row.updated_at,
    }
end

local function normalize_ingredient_row(row)
    local ingredient_id = nil
    local recipe_key = nil
    local item_key = nil
    local quantity = nil

    if type(row) ~= "table" then
        return nil
    end

    ingredient_id = normalize_positive_integer(row.id)
    recipe_key = normalize_recipe_key(row.recipe_key)
    item_key = normalize_item_key(row.item_key)
    quantity = normalize_positive_integer(row.quantity)

    if ingredient_id == nil or recipe_key == nil or item_key == nil or quantity == nil then
        return nil
    end

    return {
        id = ingredient_id,
        recipe_key = recipe_key,
        item_key = item_key,
        quantity = quantity,
        created_at = row.created_at,
    }
end

local function normalize_station_row(row)
    local station_key = nil
    local station_type = nil
    local position_x = nil
    local position_y = nil
    local position_z = nil
    local radius = nil

    if type(row) ~= "table" then
        return nil
    end

    station_key = normalize_station_key(row.key)
    station_type = normalize_station_key(row.station_type)
    position_x = normalize_coordinate(row.position_x)
    position_y = normalize_coordinate(row.position_y)
    position_z = normalize_coordinate(row.position_z)
    radius = normalize_positive_coordinate(row.radius)

    if station_key == nil or station_type == nil or position_x == nil or position_y == nil or position_z == nil or radius == nil then
        return nil
    end

    return {
        key = station_key,
        name = trim_string(row.name) or station_key,
        station_type = station_type,
        position_x = position_x,
        position_y = position_y,
        position_z = position_z,
        radius = radius,
        is_active = normalize_boolean(row.is_active, false),
        created_at = row.created_at,
        updated_at = row.updated_at,
    }
end

local function normalize_rows(rows, normalizer)
    local normalized_rows = {}

    for _, row in ipairs(rows or {}) do
        local normalized_row = normalizer(row)

        if normalized_row ~= nil then
            normalized_rows[#normalized_rows + 1] = normalized_row
        end
    end

    return normalized_rows
end

function CraftingRepository.Create(database_service)
    local self = setmetatable({}, CraftingRepository)

    self.database_service = database_service

    return self
end

function CraftingRepository:Connect(callback, reason)
    local is_connected = false
    local database_or_error = nil

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if self.database_service == nil then
        Console.Log(
            "[gr_crafting][repository] Database service unavailable during %s.",
            tostring(reason or "crafting-call")
        )
        callback(false, nil, "database-service-missing")
        return true
    end

    is_connected, database_or_error = self.database_service:Connect()

    if not is_connected then
        Console.Log(
            "[gr_crafting][repository] Database connection failed during %s with error=%s.",
            tostring(reason or "crafting-call"),
            tostring(database_or_error)
        )
        callback(false, nil, database_or_error)
        return true
    end

    callback(true, database_or_error, nil)
    return true
end

function CraftingRepository:ListActiveRecipes(callback)
    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    return self:Connect(function(is_connected, database_or_error, error)
        if not is_connected then
            callback(false, nil, error)
            return
        end

        database_or_error:SelectAsync(SELECT_ACTIVE_RECIPES_QUERY, function(rows, select_error)
            local recipe_rows = nil

            if select_error ~= nil then
                callback(false, nil, select_error)
                return
            end

            recipe_rows = normalize_rows(rows, normalize_recipe_row)

            Console.Log(
                "[gr_crafting][repository] Active recipes loaded count=%s.",
                tostring(#recipe_rows)
            )

            callback(true, recipe_rows, nil)
        end)
    end, "crafting-list-active-recipes")
end

function CraftingRepository:GetRecipeByKey(recipe_key, callback)
    local normalized_recipe_key = normalize_recipe_key(recipe_key)

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if normalized_recipe_key == nil then
        callback(false, nil, "recipe-key-required")
        return true
    end

    return self:Connect(function(is_connected, database_or_error, error)
        if not is_connected then
            callback(false, nil, error)
            return
        end

        database_or_error:SelectAsync(SELECT_RECIPE_BY_KEY_QUERY, function(rows, select_error)
            local recipe_rows = nil
            local recipe_row = nil

            if select_error ~= nil then
                callback(false, nil, select_error)
                return
            end

            recipe_rows = normalize_rows(rows, normalize_recipe_row)
            recipe_row = recipe_rows[1]

            Console.Log(
                "[gr_crafting][repository] Recipe loaded key=%s active=%s.",
                tostring(normalized_recipe_key),
                tostring(recipe_row ~= nil and recipe_row.is_active == true)
            )

            callback(true, recipe_row, nil)
        end, normalized_recipe_key)
    end, "crafting-get-recipe")
end

function CraftingRepository:ListIngredientsByRecipeKey(recipe_key, callback)
    local normalized_recipe_key = normalize_recipe_key(recipe_key)

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if normalized_recipe_key == nil then
        callback(false, nil, "recipe-key-required")
        return true
    end

    return self:Connect(function(is_connected, database_or_error, error)
        if not is_connected then
            callback(false, nil, error)
            return
        end

        database_or_error:SelectAsync(SELECT_INGREDIENTS_BY_RECIPE_KEY_QUERY, function(rows, select_error)
            local ingredient_rows = nil

            if select_error ~= nil then
                callback(false, nil, select_error)
                return
            end

            ingredient_rows = normalize_rows(rows, normalize_ingredient_row)

            Console.Log(
                "[gr_crafting][repository] Recipe ingredients loaded recipe_key=%s count=%s.",
                tostring(normalized_recipe_key),
                tostring(#ingredient_rows)
            )

            callback(true, ingredient_rows, nil)
        end, normalized_recipe_key)
    end, "crafting-list-ingredients")
end

function CraftingRepository:GetRecipeDetails(recipe_key, callback)
    local normalized_recipe_key = normalize_recipe_key(recipe_key)

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if normalized_recipe_key == nil then
        callback(false, nil, "recipe-key-required")
        return true
    end

    return self:GetRecipeByKey(normalized_recipe_key, function(is_recipe_success, recipe_row, recipe_error)
        if not is_recipe_success then
            callback(false, nil, recipe_error)
            return
        end

        if recipe_row == nil then
            callback(true, nil, nil)
            return
        end

        self:ListIngredientsByRecipeKey(normalized_recipe_key, function(is_ingredients_success, ingredient_rows, ingredients_error)
            if not is_ingredients_success then
                callback(false, nil, ingredients_error)
                return
            end

            callback(true, {
                recipe = recipe_row,
                ingredients = ingredient_rows or {},
            }, nil)
        end)
    end)
end

function CraftingRepository:GetStationByKey(station_key, callback)
    local normalized_station_key = normalize_station_key(station_key)

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if normalized_station_key == nil then
        callback(false, nil, "station-key-required")
        return true
    end

    return self:Connect(function(is_connected, database_or_error, error)
        if not is_connected then
            callback(false, nil, error)
            return
        end

        database_or_error:SelectAsync(SELECT_STATION_BY_KEY_QUERY, function(rows, select_error)
            local station_rows = nil
            local station_row = nil

            if select_error ~= nil then
                callback(false, nil, select_error)
                return
            end

            station_rows = normalize_rows(rows, normalize_station_row)
            station_row = station_rows[1]

            Console.Log(
                "[gr_crafting][repository] Station loaded key=%s active=%s.",
                tostring(normalized_station_key),
                tostring(station_row ~= nil and station_row.is_active == true)
            )

            callback(true, station_row, nil)
        end, normalized_station_key)
    end, "crafting-get-station")
end

function CraftingRepository:ListActiveStations(callback)
    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    return self:Connect(function(is_connected, database_or_error, error)
        if not is_connected then
            callback(false, nil, error)
            return
        end

        database_or_error:SelectAsync(SELECT_ACTIVE_STATIONS_QUERY, function(rows, select_error)
            local station_rows = nil

            if select_error ~= nil then
                callback(false, nil, select_error)
                return
            end

            station_rows = normalize_rows(rows, normalize_station_row)

            Console.Log(
                "[gr_crafting][repository] Active stations loaded count=%s.",
                tostring(#station_rows)
            )

            callback(true, station_rows, nil)
        end)
    end, "crafting-list-active-stations")
end

GRCrafting.Server.CraftingRepositoryClass = CraftingRepository

return CraftingRepository

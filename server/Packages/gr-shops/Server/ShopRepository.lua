GRShops = GRShops or {}
GRShops.Server = GRShops.Server or {}

local ShopRepository = {}
ShopRepository.__index = ShopRepository

local SELECT_SHOPS_QUERY = [[
    SELECT
        id,
        key,
        name,
        description,
        shop_type,
        is_active,
        created_at,
        updated_at
    FROM shops
    ORDER BY key ASC, id ASC
]]

local SELECT_SHOP_ITEMS_QUERY = [[
    SELECT
        shops.id AS shop_id,
        shops.key AS shop_key,
        shops.name AS shop_name,
        shops.description AS shop_description,
        shops.shop_type,
        shops.is_active AS shop_is_active,
        shop_items.id AS shop_item_id,
        shop_items.item_key,
        shop_items.wallet,
        shop_items.price,
        shop_items.is_active AS shop_item_is_active,
        items.name AS item_name,
        items.description AS item_description,
        items.weight AS item_weight,
        items.is_stackable,
        items.is_illegal
    FROM shops
    LEFT JOIN shop_items
        ON shop_items.shop_id = shops.id
    LEFT JOIN items
        ON items.key = shop_items.item_key
    WHERE shops.key = :0
    ORDER BY shop_items.item_key ASC, shop_items.id ASC
]]

local SELECT_SHOP_ITEM_QUERY = [[
    SELECT
        shops.id AS shop_id,
        shops.key AS shop_key,
        shops.name AS shop_name,
        shops.description AS shop_description,
        shops.shop_type,
        shops.is_active AS shop_is_active,
        shop_items.id AS shop_item_id,
        shop_items.item_key,
        shop_items.wallet,
        shop_items.price,
        shop_items.is_active AS shop_item_is_active,
        items.name AS item_name,
        items.description AS item_description,
        items.weight AS item_weight,
        items.is_stackable,
        items.is_illegal
    FROM shops
    JOIN shop_items
        ON shop_items.shop_id = shops.id
    JOIN items
        ON items.key = shop_items.item_key
    WHERE shops.key = :0
        AND shop_items.item_key = :1
    LIMIT 1
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

local function normalize_wallet(wallet)
    local normalized_wallet = trim_string(wallet)

    if normalized_wallet == nil then
        return nil
    end

    normalized_wallet = string.lower(normalized_wallet)

    if normalized_wallet ~= "cash" and normalized_wallet ~= "bank" then
        return nil
    end

    return normalized_wallet
end

local function normalize_shop_key(shop_key)
    return trim_string(shop_key)
end

local function normalize_item_key(item_key)
    return trim_string(item_key)
end

local function normalize_shop_row(row)
    local shop_id = nil
    local shop_key = nil

    if type(row) ~= "table" then
        return nil
    end

    shop_id = normalize_positive_integer(row.id)
    shop_key = normalize_shop_key(row.key)

    if shop_id == nil or shop_key == nil then
        return nil
    end

    return {
        id = shop_id,
        key = shop_key,
        name = trim_string(row.name),
        description = trim_string(row.description),
        shop_type = trim_string(row.shop_type),
        is_active = normalize_boolean(row.is_active, false),
        created_at = row.created_at,
        updated_at = row.updated_at,
    }
end

local function normalize_shop_item_row(row)
    local shop_id = nil
    local shop_item_id = nil
    local shop_key = nil
    local item_key = nil
    local wallet = nil
    local price = nil

    if type(row) ~= "table" then
        return nil
    end

    shop_id = normalize_positive_integer(row.shop_id)
    shop_item_id = normalize_positive_integer(row.shop_item_id)
    shop_key = normalize_shop_key(row.shop_key)
    item_key = normalize_item_key(row.item_key)
    wallet = normalize_wallet(row.wallet)
    price = normalize_positive_integer(row.price)

    if shop_id == nil or shop_key == nil then
        return nil
    end

    return {
        shop = {
            id = shop_id,
            key = shop_key,
            name = trim_string(row.shop_name),
            description = trim_string(row.shop_description),
            shop_type = trim_string(row.shop_type),
            is_active = normalize_boolean(row.shop_is_active, false),
        },
        shop_item_id = shop_item_id,
        item_key = item_key,
        wallet = wallet,
        price = price,
        is_active = normalize_boolean(row.shop_item_is_active, false),
        item_name = trim_string(row.item_name),
        item_description = trim_string(row.item_description),
        item_weight = tonumber(row.item_weight) or 0,
        is_stackable = normalize_boolean(row.is_stackable, false),
        is_illegal = normalize_boolean(row.is_illegal, false),
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

function ShopRepository.Create(database_service)
    local self = setmetatable({}, ShopRepository)

    self.database_service = database_service

    return self
end

function ShopRepository:Connect(callback, reason)
    local is_connected = false
    local database_or_error = nil

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if self.database_service == nil then
        Console.Log(
            "[gr_shops][repository] Database service unavailable during %s.",
            tostring(reason or "shop-call")
        )
        callback(false, nil, "database-service-missing")
        return true
    end

    is_connected, database_or_error = self.database_service:Connect()

    if not is_connected then
        Console.Log(
            "[gr_shops][repository] Database connection failed during %s with error=%s.",
            tostring(reason or "shop-call"),
            tostring(database_or_error)
        )
        callback(false, nil, database_or_error)
        return true
    end

    callback(true, database_or_error, nil)
    return true
end

function ShopRepository:ListShops(callback)
    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    return self:Connect(function(is_connected, database_or_error, error)
        if not is_connected then
            callback(false, nil, error)
            return
        end

        database_or_error:SelectAsync(SELECT_SHOPS_QUERY, function(rows, select_error)
            if select_error ~= nil then
                callback(false, nil, select_error)
                return
            end

            callback(true, normalize_rows(rows, normalize_shop_row), nil)
        end)
    end, "shops-list")
end

function ShopRepository:ListShopItems(shop_key, callback)
    local normalized_shop_key = normalize_shop_key(shop_key)

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if normalized_shop_key == nil then
        callback(false, nil, "shop-key-required")
        return true
    end

    return self:Connect(function(is_connected, database_or_error, error)
        if not is_connected then
            callback(false, nil, error)
            return
        end

        database_or_error:SelectAsync(SELECT_SHOP_ITEMS_QUERY, function(rows, select_error)
            local normalized_rows = nil

            if select_error ~= nil then
                callback(false, nil, select_error)
                return
            end

            normalized_rows = normalize_rows(rows, normalize_shop_item_row)
            callback(true, normalized_rows, nil)
        end, normalized_shop_key)
    end, "shop-items-list")
end

function ShopRepository:GetShopItem(shop_key, item_key, callback)
    local normalized_shop_key = normalize_shop_key(shop_key)
    local normalized_item_key = normalize_item_key(item_key)

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if normalized_shop_key == nil then
        callback(false, nil, "shop-key-required")
        return true
    end

    if normalized_item_key == nil then
        callback(false, nil, "item-key-required")
        return true
    end

    return self:Connect(function(is_connected, database_or_error, error)
        if not is_connected then
            callback(false, nil, error)
            return
        end

        database_or_error:SelectAsync(SELECT_SHOP_ITEM_QUERY, function(rows, select_error)
            local normalized_rows = nil

            if select_error ~= nil then
                callback(false, nil, select_error)
                return
            end

            normalized_rows = normalize_rows(rows, normalize_shop_item_row)
            callback(true, normalized_rows[1], nil)
        end, normalized_shop_key, normalized_item_key)
    end, "shop-item-get")
end

GRShops.Server.ShopRepositoryClass = ShopRepository

return ShopRepository

GRShops = GRShops or {}
GRShops.Server = GRShops.Server or {}

local ShopService = {}
ShopService.__index = ShopService

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

local function normalize_character_id(character_id)
    return normalize_positive_integer(character_id)
end

local function normalize_shop_key(shop_key)
    return trim_string(shop_key)
end

local function normalize_item_key(item_key)
    return trim_string(item_key)
end

local function normalize_quantity(quantity)
    local normalized_quantity = normalize_positive_integer(quantity)

    if normalized_quantity == nil or normalized_quantity > 100 then
        return nil
    end

    return normalized_quantity
end

local function callback_repository_missing(callback)
    if type(callback) == "function" then
        callback(false, nil, "shop-repository-missing")
    end

    return true
end

function ShopService.Create(repository)
    local self = setmetatable({}, ShopService)

    self.repository = repository

    return self
end

function ShopService:ListShops(callback)
    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if self.repository == nil then
        return callback_repository_missing(callback)
    end

    return self.repository:ListShops(callback)
end

function ShopService:ListShopItems(shop_key, callback)
    local normalized_shop_key = normalize_shop_key(shop_key)

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if self.repository == nil then
        return callback_repository_missing(callback)
    end

    if normalized_shop_key == nil then
        callback(false, nil, "shop-key-required")
        return true
    end

    return self.repository:ListShopItems(normalized_shop_key, function(is_success, shop_item_rows, error)
        local first_row = nil

        if not is_success then
            callback(false, nil, error)
            return
        end

        first_row = type(shop_item_rows) == "table" and shop_item_rows[1] or nil

        if first_row == nil then
            callback(false, nil, "shop-not-found")
            return
        end

        callback(true, shop_item_rows, nil)
    end)
end

function ShopService:BuyItem(character_id, shop_key, item_key, quantity, callback)
    local normalized_character_id = normalize_character_id(character_id)
    local normalized_shop_key = normalize_shop_key(shop_key)
    local normalized_item_key = normalize_item_key(item_key)
    local normalized_quantity = normalize_quantity(quantity)

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

    if normalized_shop_key == nil then
        callback(false, nil, "shop-key-required")
        return true
    end

    if normalized_item_key == nil then
        callback(false, nil, "item-key-required")
        return true
    end

    if normalized_quantity == nil then
        callback(false, nil, "quantity-invalid")
        return true
    end

    return self.repository:GetShopItem(normalized_shop_key, normalized_item_key, function(is_success, shop_item_row, error)
        local total_price = nil
        local reason = nil
        local metadata = nil

        if not is_success then
            callback(false, nil, "database-error")
            return
        end

        if shop_item_row == nil then
            local is_shop_list_success = false

            self.repository:ListShopItems(normalized_shop_key, function(is_list_success, shop_item_rows, list_error)
                local first_shop_row = type(shop_item_rows) == "table" and shop_item_rows[1] or nil

                is_shop_list_success = is_list_success

                if not is_shop_list_success then
                    callback(false, nil, "database-error")
                    return
                end

                if first_shop_row == nil then
                    callback(false, nil, "shop-not-found")
                    return
                end

                if first_shop_row.shop == nil or first_shop_row.shop.is_active ~= true then
                    callback(false, nil, "shop-inactive")
                    return
                end

                callback(false, nil, "shop-item-not-found")
            end)

            return
        end

        if shop_item_row.shop == nil then
            callback(false, nil, "shop-not-found")
            return
        end

        if shop_item_row.shop.is_active ~= true then
            callback(false, nil, "shop-inactive")
            return
        end

        if shop_item_row.is_active ~= true then
            callback(false, nil, "shop-item-inactive")
            return
        end

        total_price = (shop_item_row.price or 0) * normalized_quantity

        if total_price <= 0 then
            callback(false, nil, "price-invalid")
            return
        end

        if type(GREconomyBridge) ~= "table" or type(GREconomyBridge.RemoveMoney) ~= "function" then
            callback(false, nil, "economy-unavailable")
            return
        end

        if type(GRInventoryBridge) ~= "table" or type(GRInventoryBridge.AddItem) ~= "function" then
            callback(false, nil, "inventory-unavailable")
            return
        end

        reason = string.format("shop:%s:%s", normalized_shop_key, normalized_item_key)
        metadata = {
            shop_key = normalized_shop_key,
            item_key = normalized_item_key,
            quantity = normalized_quantity,
        }

        GREconomyBridge.RemoveMoney(
            normalized_character_id,
            shop_item_row.wallet,
            total_price,
            reason,
            metadata,
            function(is_payment_success, payment_result, payment_error)
                if not is_payment_success then
                    callback(false, {
                        shop_item = shop_item_row,
                        total_price = total_price,
                    }, payment_error or "payment-failed")
                    return
                end

                GRInventoryBridge.AddItem(
                    normalized_character_id,
                    normalized_item_key,
                    normalized_quantity,
                    nil,
                    function(is_inventory_success, inventory_result, inventory_error)
                        if is_inventory_success then
                            Console.Log(
                                "[gr_shops][service] Shop purchase completed character_id=%s shop_key=%s item_key=%s quantity=%s total_price=%s wallet=%s.",
                                tostring(normalized_character_id),
                                tostring(normalized_shop_key),
                                tostring(normalized_item_key),
                                tostring(normalized_quantity),
                                tostring(total_price),
                                tostring(shop_item_row.wallet)
                            )

                            callback(true, {
                                shop_item = shop_item_row,
                                quantity = normalized_quantity,
                                total_price = total_price,
                                payment = payment_result,
                                inventory = inventory_result,
                            }, nil)
                            return
                        end

                        GREconomyBridge.AddMoney(
                            normalized_character_id,
                            shop_item_row.wallet,
                            total_price,
                            "shop-rollback:" .. reason,
                            {
                                shop_key = normalized_shop_key,
                                item_key = normalized_item_key,
                                quantity = normalized_quantity,
                                rollback_reason = "inventory-add-failed",
                            },
                            function(is_rollback_success, rollback_result, rollback_error)
                                if is_rollback_success then
                                    Console.Log(
                                        "[gr_shops][service] Shop rollback completed character_id=%s shop_key=%s item_key=%s quantity=%s total_price=%s.",
                                        tostring(normalized_character_id),
                                        tostring(normalized_shop_key),
                                        tostring(normalized_item_key),
                                        tostring(normalized_quantity),
                                        tostring(total_price)
                                    )

                                    callback(false, {
                                        shop_item = shop_item_row,
                                        total_price = total_price,
                                        payment = payment_result,
                                        inventory_error = inventory_error,
                                        rollback = rollback_result,
                                    }, "inventory-add-failed")
                                    return
                                end

                                Console.Log(
                                    "[gr_shops][service] Shop rollback failed character_id=%s shop_key=%s item_key=%s quantity=%s total_price=%s reason=%s.",
                                    tostring(normalized_character_id),
                                    tostring(normalized_shop_key),
                                    tostring(normalized_item_key),
                                    tostring(normalized_quantity),
                                    tostring(total_price),
                                    tostring(rollback_error or inventory_error or "rollback-failed")
                                )

                                callback(false, {
                                    shop_item = shop_item_row,
                                    total_price = total_price,
                                    payment = payment_result,
                                    inventory_error = inventory_error,
                                    rollback_error = rollback_error,
                                }, "rollback-failed")
                            end
                        )
                    end
                )
            end
        )
    end)
end

function ShopService:SellItem(character_id, shop_key, item_key, quantity, callback)
    local normalized_character_id = normalize_character_id(character_id)
    local normalized_shop_key = normalize_shop_key(shop_key)
    local normalized_item_key = normalize_item_key(item_key)
    local normalized_quantity = normalize_quantity(quantity)

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

    if normalized_shop_key == nil then
        callback(false, nil, "shop-key-required")
        return true
    end

    if normalized_item_key == nil then
        callback(false, nil, "item-key-required")
        return true
    end

    if normalized_quantity == nil then
        callback(false, nil, "quantity-invalid")
        return true
    end

    return self.repository:GetSellableShopItem(normalized_shop_key, normalized_item_key, function(is_success, shop_item_row, error)
        local total_price = nil
        local reason = nil
        local metadata = nil

        if not is_success then
            callback(false, nil, "database-error")
            return
        end

        if shop_item_row == nil then
            self.repository:ListShopItems(normalized_shop_key, function(is_list_success, shop_item_rows, list_error)
                local first_shop_row = type(shop_item_rows) == "table" and shop_item_rows[1] or nil

                if not is_list_success then
                    callback(false, nil, "database-error")
                    return
                end

                if first_shop_row == nil then
                    callback(false, nil, "shop-not-found")
                    return
                end

                if first_shop_row.shop == nil or first_shop_row.shop.is_active ~= true then
                    callback(false, nil, "shop-inactive")
                    return
                end

                callback(false, nil, "shop-item-not-found")
            end)

            return
        end

        if shop_item_row.shop == nil then
            callback(false, nil, "shop-not-found")
            return
        end

        if shop_item_row.shop.is_active ~= true then
            callback(false, nil, "shop-inactive")
            return
        end

        if shop_item_row.is_active ~= true then
            callback(false, nil, "shop-item-inactive")
            return
        end

        if shop_item_row.is_sellable ~= true then
            callback(false, nil, "shop-item-not-sellable")
            return
        end

        total_price = (shop_item_row.sell_price or 0) * normalized_quantity

        if total_price <= 0 then
            callback(false, nil, "sell-price-invalid")
            return
        end

        if type(GRInventoryBridge) ~= "table" or type(GRInventoryBridge.RemoveItem) ~= "function" then
            callback(false, nil, "inventory-unavailable")
            return
        end

        if type(GREconomyBridge) ~= "table" or type(GREconomyBridge.AddMoney) ~= "function" then
            callback(false, nil, "economy-unavailable")
            return
        end

        reason = string.format("shop_sell:%s:%s", normalized_shop_key, normalized_item_key)
        metadata = {
            shop_key = normalized_shop_key,
            item_key = normalized_item_key,
            quantity = normalized_quantity,
        }

        GRInventoryBridge.RemoveItem(
            normalized_character_id,
            normalized_item_key,
            normalized_quantity,
            function(is_inventory_success, inventory_result, inventory_error)
                if not is_inventory_success then
                    callback(false, {
                        shop_item = shop_item_row,
                        total_price = total_price,
                    }, inventory_error or "inventory-remove-failed")
                    return
                end

                GREconomyBridge.AddMoney(
                    normalized_character_id,
                    shop_item_row.wallet,
                    total_price,
                    reason,
                    metadata,
                    function(is_payment_success, payment_result, payment_error)
                        if is_payment_success then
                            Console.Log(
                                "[gr_shops][service] Shop sellback completed character_id=%s shop_key=%s item_key=%s quantity=%s total_price=%s wallet=%s.",
                                tostring(normalized_character_id),
                                tostring(normalized_shop_key),
                                tostring(normalized_item_key),
                                tostring(normalized_quantity),
                                tostring(total_price),
                                tostring(shop_item_row.wallet)
                            )

                            callback(true, {
                                shop_item = shop_item_row,
                                quantity = normalized_quantity,
                                total_price = total_price,
                                payment = payment_result,
                                inventory = inventory_result,
                            }, nil)
                            return
                        end

                        GRInventoryBridge.AddItem(
                            normalized_character_id,
                            normalized_item_key,
                            normalized_quantity,
                            nil,
                            function(is_rollback_success, rollback_result, rollback_error)
                                if is_rollback_success then
                                    Console.Log(
                                        "[gr_shops][service] Shop sellback rollback completed character_id=%s shop_key=%s item_key=%s quantity=%s total_price=%s.",
                                        tostring(normalized_character_id),
                                        tostring(normalized_shop_key),
                                        tostring(normalized_item_key),
                                        tostring(normalized_quantity),
                                        tostring(total_price)
                                    )

                                    callback(false, {
                                        shop_item = shop_item_row,
                                        total_price = total_price,
                                        payment_error = payment_error,
                                        inventory = inventory_result,
                                        rollback = rollback_result,
                                    }, "economy-credit-failed")
                                    return
                                end

                                Console.Log(
                                    "[gr_shops][service] Shop sellback rollback failed character_id=%s shop_key=%s item_key=%s quantity=%s total_price=%s reason=%s.",
                                    tostring(normalized_character_id),
                                    tostring(normalized_shop_key),
                                    tostring(normalized_item_key),
                                    tostring(normalized_quantity),
                                    tostring(total_price),
                                    tostring(rollback_error or payment_error or "rollback-failed")
                                )

                                callback(false, {
                                    shop_item = shop_item_row,
                                    total_price = total_price,
                                    payment_error = payment_error,
                                    inventory = inventory_result,
                                    rollback_error = rollback_error,
                                }, "rollback-failed")
                            end
                        )
                    end
                )
            end
        )
    end)
end

GRShops.Server.ShopServiceClass = ShopService

return ShopService

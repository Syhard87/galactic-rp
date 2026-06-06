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
        callback(false, nil, "shop-repository-missing")
    end

    return true
end

local function validate_shop_item_stock(shop_item_row, quantity)
    if type(shop_item_row) ~= "table" then
        return false, "shop-item-not-found"
    end

    if shop_item_row.stock_enabled ~= true then
        return true, nil
    end

    if type(shop_item_row.stock_quantity) ~= "number" or shop_item_row.stock_quantity < 0 then
        return false, "stock-invalid"
    end

    if type(shop_item_row.max_stock) == "number" and shop_item_row.max_stock >= 0 then
        if shop_item_row.stock_quantity > shop_item_row.max_stock then
            return false, "stock-invalid"
        end
    end

    if shop_item_row.stock_quantity < quantity then
        return false, "stock-insufficient"
    end

    return true, nil
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

function ShopService:ValidateShopProximity(player, shop)
    local shop_location = nil
    local player_location = nil
    local distance_squared = nil
    local radius_squared = nil

    if type(shop) ~= "table" then
        return false, "shop-not-found"
    end

    if shop.requires_proximity ~= true then
        return true, nil
    end

    if type(shop.position_x) ~= "number"
        or type(shop.position_y) ~= "number"
        or type(shop.position_z) ~= "number"
        or type(shop.radius) ~= "number"
        or shop.radius <= 0
    then
        return false, "shop-position-invalid"
    end

    player_location = get_entity_location(get_controlled_character(player))

    if player_location == nil then
        return false, "player-position-unavailable"
    end

    shop_location = {
        x = shop.position_x,
        y = shop.position_y,
        z = shop.position_z,
    }

    distance_squared = get_distance_squared(player_location, shop_location)

    if distance_squared == nil then
        return false, "player-position-unavailable"
    end

    radius_squared = shop.radius * shop.radius

    if distance_squared > radius_squared then
        return false, "shop-too-far"
    end

    return true, nil
end

function ShopService:BuyItem(player, character_id, shop_key, item_key, quantity, callback)
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
        local is_stock_valid = false
        local stock_error = nil

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

        local is_near_shop, proximity_error = self:ValidateShopProximity(player, shop_item_row.shop)

        if not is_near_shop then
            callback(false, nil, proximity_error)
            return
        end

        is_stock_valid, stock_error = validate_shop_item_stock(shop_item_row, normalized_quantity)

        if not is_stock_valid then
            callback(false, nil, stock_error)
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
                local function rollback_money(stock_result, rollback_reason, final_error)
                    GREconomyBridge.AddMoney(
                        normalized_character_id,
                        shop_item_row.wallet,
                        total_price,
                        "shop-rollback:" .. reason,
                        {
                            shop_key = normalized_shop_key,
                            item_key = normalized_item_key,
                            quantity = normalized_quantity,
                            rollback_reason = rollback_reason,
                        },
                        function(is_rollback_success, rollback_result, rollback_error)
                            if is_rollback_success then
                                callback(false, {
                                    shop_item = stock_result or shop_item_row,
                                    total_price = total_price,
                                    payment = payment_result,
                                    rollback = rollback_result,
                                }, final_error)
                                return
                            end

                            Console.Log(
                                "[gr_shops][service] Shop rollback failed character_id=%s shop_key=%s item_key=%s quantity=%s total_price=%s reason=%s.",
                                tostring(normalized_character_id),
                                tostring(normalized_shop_key),
                                tostring(normalized_item_key),
                                tostring(normalized_quantity),
                                tostring(total_price),
                                tostring(rollback_error or rollback_reason or "rollback-failed")
                            )

                            callback(false, {
                                shop_item = stock_result or shop_item_row,
                                total_price = total_price,
                                payment = payment_result,
                                rollback_error = rollback_error,
                            }, "rollback-failed")
                        end
                    )
                end

                if not is_payment_success then
                    callback(false, {
                        shop_item = shop_item_row,
                        total_price = total_price,
                    }, payment_error or "payment-failed")
                    return
                end

                local function add_inventory_after_stock(stock_result)
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
                                    shop_item = stock_result or shop_item_row,
                                    quantity = normalized_quantity,
                                    total_price = total_price,
                                    payment = payment_result,
                                    inventory = inventory_result,
                                }, nil)
                                return
                            end

                            local function restore_stock_then_money()
                                if shop_item_row.stock_enabled ~= true then
                                    rollback_money(stock_result, "inventory-add-failed", "inventory-add-failed")
                                    return
                                end

                                self.repository:IncreaseShopItemStock(normalized_shop_key, normalized_item_key, normalized_quantity, function(is_restore_success, restored_stock_row, restore_error)
                                    if not is_restore_success or restored_stock_row == nil then
                                        Console.Log(
                                            "[gr_shops][service] Shop stock restore failed character_id=%s shop_key=%s item_key=%s quantity=%s total_price=%s reason=%s.",
                                            tostring(normalized_character_id),
                                            tostring(normalized_shop_key),
                                            tostring(normalized_item_key),
                                            tostring(normalized_quantity),
                                            tostring(total_price),
                                            tostring(restore_error or "stock-restore-failed")
                                        )
                                        rollback_money(stock_result, "inventory-add-failed", "rollback-failed")
                                        return
                                    end

                                    rollback_money(restored_stock_row, "inventory-add-failed", "inventory-add-failed")
                                end)
                            end

                            restore_stock_then_money()
                        end
                    )
                end

                if shop_item_row.stock_enabled ~= true then
                    add_inventory_after_stock(shop_item_row)
                    return
                end

                self.repository:DecreaseShopItemStock(normalized_shop_key, normalized_item_key, normalized_quantity, function(is_stock_update_success, stock_result, stock_update_error)
                    if is_stock_update_success and stock_result ~= nil then
                        add_inventory_after_stock(stock_result)
                        return
                    end

                    rollback_money(shop_item_row, stock_update_error or "stock-update-failed", "stock-update-failed")
                end)
            end
        )
    end)
end

function ShopService:SellItem(player, character_id, shop_key, item_key, quantity, callback)
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

        local is_near_shop, proximity_error = self:ValidateShopProximity(player, shop_item_row.shop)

        if not is_near_shop then
            callback(false, nil, proximity_error)
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

function ShopService:RestockShopItem(shop_key, item_key, quantity, callback)
    local normalized_shop_key = normalize_shop_key(shop_key)
    local normalized_item_key = normalize_item_key(item_key)
    local normalized_quantity = normalize_positive_integer(quantity)

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

    if normalized_item_key == nil then
        callback(false, nil, "item-key-required")
        return true
    end

    if normalized_quantity == nil or normalized_quantity > 1000 then
        callback(false, nil, "quantity-invalid")
        return true
    end

    return self.repository:GetShopItem(normalized_shop_key, normalized_item_key, function(is_success, shop_item_row, error)
        if not is_success then
            callback(false, nil, "database-error")
            return
        end

        if shop_item_row == nil then
            callback(false, nil, "shop-item-not-found")
            return
        end

        if shop_item_row.stock_enabled ~= true then
            callback(false, nil, "stock-disabled")
            return
        end

        if type(shop_item_row.stock_quantity) ~= "number" or shop_item_row.stock_quantity < 0 then
            callback(false, nil, "stock-invalid")
            return
        end

        return self.repository:IncreaseShopItemStock(normalized_shop_key, normalized_item_key, normalized_quantity, function(is_restock_success, updated_row, restock_error)
            if not is_restock_success or updated_row == nil then
                callback(false, nil, restock_error or "stock-update-failed")
                return
            end

            callback(true, updated_row, nil)
        end)
    end)
end

GRShops.Server.ShopServiceClass = ShopService

return ShopService

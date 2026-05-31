GRInventory = GRInventory or {}
GRInventory.Server = GRInventory.Server or {}

local InventoryRepository = {}
InventoryRepository.__index = InventoryRepository

local SELECT_ITEM_BY_KEY_QUERY = [[
    SELECT
        key,
        name,
        description,
        weight,
        is_stackable,
        is_illegal,
        created_at,
        updated_at
    FROM items
    WHERE key = :0
    LIMIT 1
]]

local SELECT_INVENTORY_BY_CHARACTER_ID_QUERY = [[
    SELECT
        ii.id,
        ii.character_id,
        ii.item_key,
        ii.quantity,
        ii.metadata_json,
        ii.created_at,
        ii.updated_at,
        i.name AS item_name,
        i.description AS item_description,
        i.weight AS item_weight,
        i.is_stackable,
        i.is_illegal
    FROM inventory_items ii
    JOIN items i
        ON i.key = ii.item_key
    WHERE ii.character_id = :0
    ORDER BY i.name ASC, ii.id ASC
]]

local SELECT_STACKABLE_INVENTORY_ENTRY_QUERY = [[
    SELECT
        id,
        character_id,
        item_key,
        quantity,
        metadata_json,
        created_at,
        updated_at
    FROM inventory_items
    WHERE
        character_id = :0
        AND item_key = :1
        AND metadata_json = '{}'::JSONB
    ORDER BY id ASC
    LIMIT 1
]]

local INSERT_INVENTORY_ITEM_QUERY = [[
    INSERT INTO inventory_items (
        character_id,
        item_key,
        quantity,
        metadata_json
    )
    VALUES (
        :0,
        :1,
        :2,
        CAST(:3 AS JSONB)
    )
    RETURNING
        id,
        character_id,
        item_key,
        quantity,
        metadata_json,
        created_at,
        updated_at
]]

local UPDATE_INVENTORY_ITEM_QUANTITY_INCREMENT_QUERY = [[
    UPDATE inventory_items
    SET
        quantity = quantity + :0,
        updated_at = NOW()
    WHERE id = :1
]]

local UPDATE_INVENTORY_ITEM_QUANTITY_SET_QUERY = [[
    UPDATE inventory_items
    SET
        quantity = :0,
        updated_at = NOW()
    WHERE id = :1
]]

local DELETE_INVENTORY_ITEM_QUERY = [[
    DELETE FROM inventory_items
    WHERE id = :0
]]

local SELECT_INVENTORY_ROWS_FOR_REMOVAL_QUERY = [[
    SELECT
        id,
        character_id,
        item_key,
        quantity,
        metadata_json,
        created_at,
        updated_at
    FROM inventory_items
    WHERE
        character_id = :0
        AND item_key = :1
    ORDER BY id ASC
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

    if type(value) == "string" then
        if value:match("^%d+$") == nil then
            return nil
        end

        local parsed_value = tonumber(value)

        if parsed_value == nil or parsed_value < 1 then
            return nil
        end

        return math.floor(parsed_value)
    end

    return nil
end

local function normalize_item_key(item_key)
    return trim_string(item_key)
end

local function normalize_metadata_json(metadata_json)
    if metadata_json == nil then
        return "{}"
    end

    if type(metadata_json) ~= "string" then
        return nil
    end

    local trimmed_metadata = metadata_json:match("^%s*(.-)%s*$")

    if trimmed_metadata == "" or trimmed_metadata == "{}" or trimmed_metadata == "{ }" then
        return "{}"
    end

    return trimmed_metadata
end

local function is_empty_metadata_json(metadata_json)
    return metadata_json == "{}"
end

local function normalize_item_row(row)
    local item_key = nil

    if type(row) ~= "table" then
        return nil
    end

    item_key = normalize_item_key(row.key)

    if item_key == nil then
        return nil
    end

    return {
        key = item_key,
        name = row.name,
        description = row.description,
        weight = tonumber(row.weight) or 0,
        is_stackable = row.is_stackable == true,
        is_illegal = row.is_illegal == true,
        created_at = row.created_at,
        updated_at = row.updated_at,
    }
end

local function normalize_inventory_row(row)
    local inventory_id = nil
    local character_id = nil
    local item_key = nil
    local quantity = nil

    if type(row) ~= "table" then
        return nil
    end

    inventory_id = normalize_positive_integer(row.id)
    character_id = normalize_positive_integer(row.character_id)
    item_key = normalize_item_key(row.item_key)
    quantity = normalize_positive_integer(row.quantity)

    if inventory_id == nil or character_id == nil or item_key == nil or quantity == nil then
        return nil
    end

    return {
        id = inventory_id,
        character_id = character_id,
        item_key = item_key,
        quantity = quantity,
        metadata_json = row.metadata_json or "{}",
        created_at = row.created_at,
        updated_at = row.updated_at,
        item_name = row.item_name,
        item_description = row.item_description,
        item_weight = tonumber(row.item_weight) or 0,
        is_stackable = row.is_stackable == true,
        is_illegal = row.is_illegal == true,
    }
end

local function normalize_rows(rows, normalizer)
    local normalized_rows = {}

    if type(rows) ~= "table" then
        return normalized_rows
    end

    for _, row in ipairs(rows) do
        local normalized_row = normalizer(row)

        if normalized_row ~= nil then
            normalized_rows[#normalized_rows + 1] = normalized_row
        end
    end

    return normalized_rows
end

function InventoryRepository.Create(database_service)
    local self = setmetatable({}, InventoryRepository)

    self.database_service = database_service

    return self
end

function InventoryRepository:Connect(callback, reason)
    local is_connected = false
    local database_or_error = nil

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if self.database_service == nil then
        Console.Log(
            "[gr_inventory][repository] Database service unavailable during %s.",
            tostring(reason or "repository-call")
        )

        callback(false, nil, "database-service-missing")
        return true
    end

    is_connected, database_or_error = self.database_service:Connect()

    if not is_connected then
        Console.Log(
            "[gr_inventory][repository] Database connection failed during %s with error=%s.",
            tostring(reason or "repository-call"),
            tostring(database_or_error)
        )

        callback(false, nil, database_or_error)
        return true
    end

    callback(true, database_or_error, nil)
    return true
end

function InventoryRepository:ListInventory(character_id, callback)
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

        database_or_error:SelectAsync(SELECT_INVENTORY_BY_CHARACTER_ID_QUERY, function(rows, select_error)
            local normalized_rows = nil

            if select_error ~= nil then
                callback(false, nil, select_error)
                return
            end

            normalized_rows = normalize_rows(rows, normalize_inventory_row)

            Console.Log(
                "[gr_inventory][repository] Inventory list loaded character_id=%s count=%s.",
                tostring(normalized_character_id),
                tostring(#normalized_rows)
            )

            callback(true, normalized_rows, nil)
        end, normalized_character_id)
    end, "inventory-list")
end

function InventoryRepository:GetItemByKey(item_key, callback)
    local normalized_item_key = normalize_item_key(item_key)

    if type(callback) ~= "function" then
        return false, "callback-required"
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

        database_or_error:SelectAsync(SELECT_ITEM_BY_KEY_QUERY, function(rows, select_error)
            local normalized_rows = nil

            if select_error ~= nil then
                callback(false, nil, select_error)
                return
            end

            normalized_rows = normalize_rows(rows, normalize_item_row)
            callback(true, normalized_rows[1], nil)
        end, normalized_item_key)
    end, "item-by-key")
end

function InventoryRepository:AddItem(character_id, item_key, quantity, metadata_json, callback)
    local normalized_character_id = normalize_positive_integer(character_id)
    local normalized_item_key = normalize_item_key(item_key)
    local normalized_quantity = normalize_positive_integer(quantity)
    local normalized_metadata_json = normalize_metadata_json(metadata_json)

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if normalized_character_id == nil then
        callback(false, nil, "character-id-required")
        return true
    end

    if normalized_item_key == nil then
        callback(false, nil, "item-key-required")
        return true
    end

    if normalized_quantity == nil then
        callback(false, nil, "quantity-required")
        return true
    end

    if normalized_metadata_json == nil then
        callback(false, nil, "metadata-json-invalid")
        return true
    end

    self:GetItemByKey(normalized_item_key, function(is_success, item_row, error)
        if not is_success then
            callback(false, nil, error)
            return
        end

        if item_row == nil then
            callback(false, nil, "item-not-found")
            return
        end

        self:Connect(function(is_connected, database_or_error, connect_error)
            if not is_connected then
                callback(false, nil, connect_error)
                return
            end

            local function insert_inventory_row()
                database_or_error:SelectAsync(
                    INSERT_INVENTORY_ITEM_QUERY,
                    function(rows, insert_error)
                        if insert_error ~= nil then
                            callback(false, nil, insert_error)
                            return
                        end

                        local normalized_rows = normalize_rows(rows, normalize_inventory_row)

                        Console.Log(
                            "[gr_inventory][repository] Item added character_id=%s item_key=%s quantity=%s.",
                            tostring(normalized_character_id),
                            tostring(normalized_item_key),
                            tostring(normalized_quantity)
                        )

                        callback(true, {
                            item = item_row,
                            inventory_row = normalized_rows[1],
                            character_id = normalized_character_id,
                            item_key = normalized_item_key,
                            quantity = normalized_quantity,
                        }, nil)
                    end,
                    normalized_character_id,
                    normalized_item_key,
                    normalized_quantity,
                    normalized_metadata_json
                )
            end

            if item_row.is_stackable == true and is_empty_metadata_json(normalized_metadata_json) then
                database_or_error:SelectAsync(
                    SELECT_STACKABLE_INVENTORY_ENTRY_QUERY,
                    function(rows, select_error)
                        local normalized_rows = nil

                        if select_error ~= nil then
                            callback(false, nil, select_error)
                            return
                        end

                        normalized_rows = normalize_rows(rows, normalize_inventory_row)

                        if normalized_rows[1] == nil then
                            insert_inventory_row()
                            return
                        end

                        database_or_error:ExecuteAsync(
                            UPDATE_INVENTORY_ITEM_QUANTITY_INCREMENT_QUERY,
                            function(rows_affected, update_error)
                                if update_error ~= nil then
                                    callback(false, nil, update_error)
                                    return
                                end

                                if rows_affected ~= 1 then
                                    callback(false, nil, "inventory-item-update-unexpected-rows-affected")
                                    return
                                end

                                Console.Log(
                                    "[gr_inventory][repository] Item added character_id=%s item_key=%s quantity=%s.",
                                    tostring(normalized_character_id),
                                    tostring(normalized_item_key),
                                    tostring(normalized_quantity)
                                )

                                callback(true, {
                                    item = item_row,
                                    inventory_row = normalized_rows[1],
                                    character_id = normalized_character_id,
                                    item_key = normalized_item_key,
                                    quantity = normalized_quantity,
                                }, nil)
                            end,
                            normalized_quantity,
                            normalized_rows[1].id
                        )
                    end,
                    normalized_character_id,
                    normalized_item_key
                )

                return
            end

            -- MVP choice: non-stackable items still use the quantity column on their own rows.
            insert_inventory_row()
        end, "add-item")
    end)

    return true
end

function InventoryRepository:RemoveItem(character_id, item_key, quantity, callback)
    local normalized_character_id = normalize_positive_integer(character_id)
    local normalized_item_key = normalize_item_key(item_key)
    local normalized_quantity = normalize_positive_integer(quantity)

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if normalized_character_id == nil then
        callback(false, nil, "character-id-required")
        return true
    end

    if normalized_item_key == nil then
        callback(false, nil, "item-key-required")
        return true
    end

    if normalized_quantity == nil then
        callback(false, nil, "quantity-required")
        return true
    end

    return self:Connect(function(is_connected, database_or_error, error)
        if not is_connected then
            callback(false, nil, error)
            return
        end

        database_or_error:SelectAsync(
            SELECT_INVENTORY_ROWS_FOR_REMOVAL_QUERY,
            function(rows, select_error)
                local normalized_rows = nil
                local total_quantity = 0
                local remaining_quantity = normalized_quantity

                if select_error ~= nil then
                    callback(false, nil, select_error)
                    return
                end

                normalized_rows = normalize_rows(rows, normalize_inventory_row)

                for _, inventory_row in ipairs(normalized_rows) do
                    total_quantity = total_quantity + inventory_row.quantity
                end

                if total_quantity < normalized_quantity then
                    callback(false, nil, "inventory-item-quantity-insufficient")
                    return
                end

                local function process_next_row(index)
                    local inventory_row = normalized_rows[index]

                    if remaining_quantity <= 0 or inventory_row == nil then
                        Console.Log(
                            "[gr_inventory][repository] Item removed character_id=%s item_key=%s quantity=%s.",
                            tostring(normalized_character_id),
                            tostring(normalized_item_key),
                            tostring(normalized_quantity)
                        )

                        callback(true, {
                            character_id = normalized_character_id,
                            item_key = normalized_item_key,
                            quantity = normalized_quantity,
                        }, nil)
                        return
                    end

                    if inventory_row.quantity <= remaining_quantity then
                        remaining_quantity = remaining_quantity - inventory_row.quantity

                        database_or_error:ExecuteAsync(
                            DELETE_INVENTORY_ITEM_QUERY,
                            function(rows_affected, delete_error)
                                if delete_error ~= nil then
                                    callback(false, nil, delete_error)
                                    return
                                end

                                if rows_affected ~= 1 then
                                    callback(false, nil, "inventory-item-delete-unexpected-rows-affected")
                                    return
                                end

                                process_next_row(index + 1)
                            end,
                            inventory_row.id
                        )

                        return
                    end

                    database_or_error:ExecuteAsync(
                        UPDATE_INVENTORY_ITEM_QUANTITY_SET_QUERY,
                        function(rows_affected, update_error)
                            if update_error ~= nil then
                                callback(false, nil, update_error)
                                return
                            end

                            if rows_affected ~= 1 then
                                callback(false, nil, "inventory-item-update-unexpected-rows-affected")
                                return
                            end

                            remaining_quantity = 0
                            process_next_row(index + 1)
                        end,
                        inventory_row.quantity - remaining_quantity,
                        inventory_row.id
                    )
                end

                process_next_row(1)
            end,
            normalized_character_id,
            normalized_item_key
        )
    end, "remove-item")
end

GRInventory.Server.InventoryRepositoryClass = InventoryRepository

return InventoryRepository

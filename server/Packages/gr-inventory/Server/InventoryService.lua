GRInventory = GRInventory or {}
GRInventory.Server = GRInventory.Server or {}

local InventoryService = {}
InventoryService.__index = InventoryService

local function callback_repository_missing(callback)
    if type(callback) == "function" then
        callback(false, nil, "inventory-repository-missing")
    end

    return true
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

    return active_character.id, nil
end

function InventoryService.Create(repository)
    local self = setmetatable({}, InventoryService)

    self.repository = repository

    return self
end

function InventoryService:ListInventory(character_id, callback)
    if self.repository == nil then
        return callback_repository_missing(callback)
    end

    return self.repository:ListInventory(character_id, callback)
end

function InventoryService:ListActiveCharacterInventory(player_or_platform_id, callback)
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

    return self.repository:ListInventory(active_character_id, callback)
end

function InventoryService:AddItem(character_id, item_key, quantity, metadata_json, callback)
    if self.repository == nil then
        return callback_repository_missing(callback)
    end

    return self.repository:AddItem(character_id, item_key, quantity, metadata_json, callback)
end

function InventoryService:AddItemToActiveCharacter(player_or_platform_id, item_key, quantity, metadata_json, callback)
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

    return self.repository:AddItem(active_character_id, item_key, quantity, metadata_json, callback)
end

function InventoryService:RemoveItem(character_id, item_key, quantity, callback)
    if self.repository == nil then
        return callback_repository_missing(callback)
    end

    return self.repository:RemoveItem(character_id, item_key, quantity, callback)
end

GRInventory.Server.InventoryServiceClass = InventoryService

return InventoryService

GRCharacters = GRCharacters or {}
GRCharacters.Server = GRCharacters.Server or {}

local CharacterService = {}
CharacterService.__index = CharacterService

local function normalize_platform_key(player_or_id)
    if type(player_or_id) == "string" then
        return player_or_id
    end

    if type(player_or_id) ~= "table" and type(player_or_id) ~= "userdata" then
        return nil
    end

    -- Verified against local nanos world API metadata:
    -- external/nanos-world-docs/src/api/Classes/Player.json
    if type(player_or_id.GetAccountID) == "function" then
        return player_or_id:GetAccountID()
    end

    if type(player_or_id.platform_id) == "string" or type(player_or_id.platform_id) == "number" then
        return tostring(player_or_id.platform_id)
    end

    return nil
end

local function normalize_position(position)
    if type(position) ~= "table" and type(position) ~= "userdata" then
        return nil
    end

    if type(position.x) ~= "number" or type(position.y) ~= "number" or type(position.z) ~= "number" then
        return nil
    end

    return {
        x = position.x,
        y = position.y,
        z = position.z,
    }
end

function CharacterService.Create(repository, creation_service, player_service, selection_service)
    local self = setmetatable({}, CharacterService)

    self.repository = repository
    self.creation_service = creation_service
    self.player_service = player_service
    self.selection_service = selection_service

    return self
end

function CharacterService:LoadPlayerSession(player, callback)
    if self.player_service == nil then
        return false, "player-service-missing"
    end

    return self.player_service:LoadPlayerSession(player, function(is_success, player_state)
        if not is_success then
            if type(callback) == "function" then
                callback(false, player_state)
            end

            return
        end

        if self.selection_service == nil or player_state == nil or player_state.status ~= "player-row-loaded" then
            if type(callback) == "function" then
                callback(true, player_state)
            end

            return
        end

        local is_started, error = self.selection_service:LoadCharactersForPlayer(player, function(list_success, selection_state)
            if type(callback) == "function" then
                callback(list_success, selection_state)
            end
        end)

        if not is_started and type(callback) == "function" then
            callback(false, {
                code = error,
                status = "blocked",
            })
        end
    end)
end

function CharacterService:GetLoadedPlayerRow(player_or_platform_id)
    if self.player_service == nil then
        return nil
    end

    return self.player_service:GetLoadedPlayerRow(player_or_platform_id)
end

function CharacterService:GetPlayerLoadState(player_or_platform_id)
    if self.player_service == nil then
        return nil
    end

    return self.player_service:GetPlayerLoadState(player_or_platform_id)
end

function CharacterService:GetCharacterSelectionState(player_or_platform_id)
    if self.selection_service == nil then
        return nil
    end

    return self.selection_service:GetSelectionState(player_or_platform_id)
end

function CharacterService:GetCachedCharacterList(player_or_platform_id)
    if self.selection_service == nil then
        return {}
    end

    return self.selection_service:GetCachedCharacterList(player_or_platform_id)
end

function CharacterService:ForgetPlayerSession(player_or_platform_id)
    local cleared_selection = true
    local cleared_player = true
    local selection_error = nil
    local player_error = nil

    if self.selection_service ~= nil then
        cleared_selection, selection_error = self.selection_service:InvalidatePlayerState(player_or_platform_id)
    end

    if self.player_service ~= nil then
        cleared_player, player_error = self.player_service:ForgetPlayerSession(player_or_platform_id)
    else
        cleared_player = false
        player_error = "player-service-missing"
    end

    if not cleared_selection then
        return false, selection_error
    end

    if not cleared_player then
        return false, player_error
    end

    return true
end

function CharacterService:GetCharactersForPlayer(player_or_platform_id, callback)
    if self.selection_service == nil then
        return false, "selection-service-missing"
    end

    return self.selection_service:LoadCharactersForPlayer(player_or_platform_id, callback)
end

function CharacterService:CreateCharacter(player_or_id, character_payload, callback)
    if self.creation_service == nil then
        return false, "creation-service-missing"
    end

    local player_target = player_or_id
    local loaded_player_row = self:GetLoadedPlayerRow(player_or_id)

    if loaded_player_row ~= nil then
        player_target = loaded_player_row
    end

    return self.creation_service:CreateCharacterForPlayer(player_target, character_payload, function(is_success, result)
        if is_success and self.selection_service ~= nil then
            self.selection_service:InvalidatePlayerState(player_or_id)
        end

        if type(callback) == "function" then
            callback(is_success, result)
        end
    end)
end

function CharacterService:SelectActiveCharacter(player_or_platform_id, character_id, callback)
    if self.selection_service == nil then
        return false, "selection-service-missing"
    end

    return self.selection_service:SelectCharacterForPlayer(player_or_platform_id, character_id, callback)
end

function CharacterService:SaveActiveCharacterPosition(player_or_id, position)
    local platform_id = normalize_platform_key(player_or_id)

    if platform_id == nil then
        return false, "player-id-required"
    end

    local normalized_position = normalize_position(position)

    if normalized_position == nil then
        return false, "position-required"
    end

    if self.selection_service == nil then
        return false, "selection-service-missing"
    end

    local character_id = self.selection_service:GetActiveCharacterId(platform_id)

    if character_id == nil then
        return false, "active-character-required"
    end

    Console.Log(
        "[gr_characters][service] Position save requested for platform_id=%s character_id=%s.",
        tostring(platform_id),
        tostring(character_id)
    )

    return self.repository:SaveCharacterPosition(character_id, normalized_position)
end

function CharacterService:GetActiveCharacterId(player_or_platform_id)
    if self.selection_service == nil then
        return nil
    end

    return self.selection_service:GetActiveCharacterId(player_or_platform_id)
end

function CharacterService:GetActiveCharacterRow(player_or_platform_id)
    if self.selection_service == nil then
        return nil
    end

    return self.selection_service:GetActiveCharacterRow(player_or_platform_id)
end

GRCharacters.Server.CharacterServiceClass = CharacterService

return CharacterService

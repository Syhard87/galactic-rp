GRCharacters = GRCharacters or {}
GRCharacters.Server = GRCharacters.Server or {}

local CharacterService = {}
CharacterService.__index = CharacterService

function CharacterService.Create(repository, creation_service, player_service, selection_service, position_service)
    local self = setmetatable({}, CharacterService)

    self.repository = repository
    self.creation_service = creation_service
    self.player_service = player_service
    self.selection_service = selection_service
    self.position_service = position_service

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

function CharacterService:SaveActiveCharacterPosition(player_or_id, callback, options)
    if self.position_service == nil then
        if type(callback) == "function" then
            callback(false, {
                code = "position-service-missing",
            })
        end

        return true
    end

    return self.position_service:SaveActiveCharacterPosition(player_or_id, callback, options)
end

function CharacterService:StartPositionAutoSave()
    if self.position_service == nil then
        return false, "position-service-missing"
    end

    return self.position_service:StartAutoSave()
end

function CharacterService:StopPositionAutoSave()
    if self.position_service == nil then
        return false, "position-service-missing"
    end

    return self.position_service:StopAutoSave()
end

function CharacterService:GetPositionSavePolicy()
    if self.position_service == nil then
        return nil
    end

    return self.position_service:GetPolicy()
end

function CharacterService:ResolveActiveCharacterSpawnData(player_or_platform_id)
    if self.position_service == nil then
        return false, {
            code = "position-service-missing",
        }
    end

    return self.position_service:ResolveSpawnDataForActiveCharacter(player_or_platform_id)
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

function CharacterService:ForgetPlayerPositionState(player_or_platform_id)
    if self.position_service == nil then
        return false, "position-service-missing"
    end

    return self.position_service:ForgetPlayerPositionState(player_or_platform_id)
end

GRCharacters.Server.CharacterServiceClass = CharacterService

return CharacterService

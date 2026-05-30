GRCharacters = GRCharacters or {}
GRCharacters.Server = GRCharacters.Server or {}

local CharacterService = {}
CharacterService.__index = CharacterService

local STATUS_PENDING_CHARACTER_CREATION = "pending-character-creation"

local function normalize_platform_id(player_or_platform_id)
    if type(player_or_platform_id) == "string" then
        if player_or_platform_id == "" then
            return nil
        end

        return player_or_platform_id
    end

    if type(player_or_platform_id) ~= "table" and type(player_or_platform_id) ~= "userdata" then
        return nil
    end

    if type(player_or_platform_id.GetAccountID) == "function" then
        return player_or_platform_id:GetAccountID()
    end

    if type(player_or_platform_id.platform_id) == "string" and player_or_platform_id.platform_id ~= "" then
        return player_or_platform_id.platform_id
    end

    return nil
end

function CharacterService.Create(repository, creation_service, player_service, selection_service, position_service, session_state)
    local self = setmetatable({}, CharacterService)

    self.repository = repository
    self.creation_service = creation_service
    self.player_service = player_service
    self.selection_service = selection_service
    self.position_service = position_service
    self.session_state = session_state
    self.creation_in_flight_by_platform_id = {}

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

function CharacterService:GetCharacterSessionStatus(player_or_platform_id)
    if self.session_state == nil then
        return nil
    end

    return self.session_state:GetStatus(player_or_platform_id)
end

function CharacterService:HasActiveCharacter(player_or_platform_id)
    if self.session_state == nil then
        return false
    end

    return self.session_state:HasActiveCharacter(player_or_platform_id)
end

function CharacterService:IsGameplayReady(player_or_platform_id)
    if self.session_state == nil then
        return false, "session-state-missing"
    end

    return self.session_state:IsGameplayReady(player_or_platform_id)
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

    if self.session_state ~= nil then
        self.session_state:Clear(player_or_platform_id)
    end

    local platform_id = normalize_platform_id(player_or_platform_id)

    if platform_id ~= nil then
        self.creation_in_flight_by_platform_id[platform_id] = nil
    end

    return true
end

function CharacterService:GetCharactersForPlayer(player_or_platform_id, callback)
    if self.selection_service == nil then
        return false, "selection-service-missing"
    end

    return self.selection_service:LoadCharactersForPlayer(player_or_platform_id, callback)
end

function CharacterService:CreateCharacterAndSelect(player_or_platform_id, character_payload, callback)
    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if self.creation_service == nil then
        return false, "creation-service-missing"
    end

    if self.selection_service == nil then
        return false, "selection-service-missing"
    end

    local platform_id = normalize_platform_id(player_or_platform_id)

    if platform_id == nil then
        callback(false, {
            code = "platform-id-required",
        })

        return true
    end

    local session_status = self:GetCharacterSessionStatus(platform_id)

    if session_status ~= STATUS_PENDING_CHARACTER_CREATION then
        callback(false, {
            code = "character-creation-not-pending",
            platform_id = platform_id,
            status = session_status or "missing",
        })

        return true
    end

    local loaded_player_row = self:GetLoadedPlayerRow(platform_id)

    if loaded_player_row == nil then
        callback(false, {
            code = "player-not-loaded",
            platform_id = platform_id,
        })

        return true
    end

    if self.creation_in_flight_by_platform_id[platform_id] == true then
        callback(false, {
            code = "character-creation-already-in-flight",
            platform_id = platform_id,
            player_id = loaded_player_row.id,
        })

        return true
    end

    Console.Log(
        "[gr_characters][server] Creating character from pending session for platform_id=%s player_id=%s.",
        tostring(platform_id),
        tostring(loaded_player_row.id)
    )

    self.creation_in_flight_by_platform_id[platform_id] = true

    local is_creation_started, creation_error = self.creation_service:CreateCharacterForPlayer(loaded_player_row, character_payload, function(is_success, result)
        self.creation_in_flight_by_platform_id[platform_id] = nil

        if not is_success then
            local error_code = result and result.code or "character-create-failed"

            if self.session_state ~= nil then
                if error_code == "character-validation-failed" then
                    self.session_state:SetPendingCharacterCreation(platform_id, loaded_player_row.id)
                else
                    self.session_state:SetFailed(platform_id, error_code)
                end
            end

            Console.Log(
                "[gr_characters][server] Character creation failed for platform_id=%s with code=%s.",
                tostring(platform_id),
                tostring(error_code)
            )

            callback(false, result)
            return
        end

        local created_character = result and result.character

        if type(created_character) ~= "table" or created_character.id == nil then
            if self.session_state ~= nil then
                self.session_state:SetFailed(platform_id, "created-character-missing")
            end

            callback(false, {
                code = "created-character-missing",
                platform_id = platform_id,
                player_id = loaded_player_row.id,
            })
            return
        end

        if self.selection_service ~= nil then
            self.selection_service:InvalidatePlayerState(platform_id)
        end

        local is_selection_started, selection_error = self:SelectActiveCharacter(platform_id, created_character.id, function(is_selected, selection_result)
            if not is_selected then
                if self.session_state ~= nil then
                    self.session_state:SetFailed(platform_id, selection_result and selection_result.code or "created-character-selection-failed")
                end

                callback(false, {
                    code = "created-character-selection-failed",
                    platform_id = platform_id,
                    player_id = loaded_player_row.id,
                    character_id = created_character.id,
                    cause = selection_result,
                })
                return
            end

            local is_ready, readiness_reason = self:IsGameplayReady(platform_id)

            Console.Log(
                "[gr_characters][server] Character created and selected for platform_id=%s character_id=%s gameplay-ready=%s.",
                tostring(platform_id),
                tostring(selection_result and selection_result.active_character_id or created_character.id),
                tostring(is_ready)
            )

            callback(true, {
                status = "character-created-and-selected",
                platform_id = platform_id,
                player_id = loaded_player_row.id,
                active_character_id = selection_result and selection_result.active_character_id or created_character.id,
                character = selection_result and selection_result.character or created_character,
                creation = result,
                selection = selection_result,
                gameplay_ready = is_ready,
                readiness_reason = readiness_reason,
            })
        end)

        if not is_selection_started then
            if self.session_state ~= nil then
                self.session_state:SetFailed(platform_id, selection_error)
            end

            callback(false, {
                code = "created-character-selection-dispatch-failed",
                platform_id = platform_id,
                player_id = loaded_player_row.id,
                character_id = created_character.id,
                cause = selection_error,
            })
        end
    end)

    if not is_creation_started then
        self.creation_in_flight_by_platform_id[platform_id] = nil
        return false, creation_error
    end

    return true
end

function CharacterService:CreateCharacter(player_or_id, character_payload, callback)
    return self:CreateCharacterAndSelect(player_or_id, character_payload, callback)
end

function CharacterService:CreateCharacterForPlayer(player_or_platform_id, character_payload, callback)
    return self:CreateCharacterAndSelect(player_or_platform_id, character_payload, callback)
end

function CharacterService:SelectActiveCharacter(player_or_platform_id, character_id, callback)
    if self.selection_service == nil then
        return false, "selection-service-missing"
    end

    return self.selection_service:SelectCharacterForPlayer(player_or_platform_id, character_id, function(is_success, result)
        if is_success and self.session_state ~= nil and type(result) == "table" then
            local active_character = result.character or result.active_character

            if type(active_character) ~= "table" then
                active_character = self:GetActiveCharacterRow(result.platform_id or player_or_platform_id)
            end

            self.session_state:SetActiveCharacter(result.platform_id, result.player_id, active_character)
        end

        if type(callback) == "function" then
            callback(is_success, result)
        end
    end)
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

function CharacterService:GetActiveCharacterSpawnTransform(player_or_platform_id)
    return self:ResolveActiveCharacterSpawnData(player_or_platform_id)
end

function CharacterService:SpawnActiveCharacter(player_or_platform_id, options)
    if self.position_service == nil then
        return false, {
            code = "position-service-missing",
        }
    end

    if not self:HasActiveCharacter(player_or_platform_id) then
        Console.Log("[gr_characters][server] active character spawn refused because no active character.")

        return false, {
            code = "active-character-required",
        }
    end

    if type(self.position_service.SpawnActiveCharacter) ~= "function" then
        return false, {
            code = "active-character-spawn-api-missing",
        }
    end

    return self.position_service:SpawnActiveCharacter(player_or_platform_id, options)
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

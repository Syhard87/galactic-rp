GRCharacters = GRCharacters or {}
GRCharacters.Server = GRCharacters.Server or {}

local CharacterFlowService = {}
CharacterFlowService.__index = CharacterFlowService

local function resolve_character_count(selection_state)
    if type(selection_state) ~= "table" then
        return 0
    end

    if type(selection_state.character_count) == "number" then
        return selection_state.character_count
    end

    if type(selection_state.characters) ~= "table" then
        return 0
    end

    return #selection_state.characters
end

local function resolve_first_character(selection_state)
    if type(selection_state) ~= "table" or type(selection_state.characters) ~= "table" then
        return nil
    end

    return selection_state.characters[1]
end

function CharacterFlowService.Create(character_service, player_service, dev_tool, session_state)
    local self = setmetatable({}, CharacterFlowService)

    self.character_service = character_service
    self.player_service = player_service
    self.dev_tool = dev_tool
    self.session_state = session_state

    return self
end

function CharacterFlowService:ResolveObservedUsername(player, platform_id)
    if self.player_service == nil then
        return tostring(platform_id)
    end

    local is_success, observed_username_or_error = self.player_service:ResolveObservedUsername(player)

    if is_success then
        return observed_username_or_error
    end

    Console.Log(
        "[gr_characters][server] Unable to resolve player name for platform_id=%s. Falling back to platform_id for DB username.",
        tostring(platform_id)
    )

    return tostring(platform_id)
end

function CharacterFlowService:SelectFirstCharacter(platform_id, selection_state)
    local first_character = resolve_first_character(selection_state)

    if type(first_character) ~= "table" or first_character.id == nil then
        if self.session_state ~= nil then
            self.session_state:SetPendingCharacterCreation(
                platform_id,
                selection_state and selection_state.player_id or nil
            )
        end

        Console.Log(
            "[gr_characters][server] No selectable character is available for platform_id=%s after character list loading.",
            tostring(platform_id)
        )
        Console.Log("[gr_characters][server] No active character selected. Character creation UI will be required later.")
        return
    end

    local is_started, error = self.character_service:SelectActiveCharacter(platform_id, first_character.id, function(is_success, result)
        if not is_success then
            if self.session_state ~= nil then
                self.session_state:SetFailed(platform_id, result and result.code or "selection-failed")
            end

            Console.Log(
                "[gr_characters][server] Active character selection failed for platform_id=%s with code=%s.",
                tostring(platform_id),
                tostring(result and result.code or "selection-failed")
            )

            return
        end

        Console.Log(
            "[gr_characters][server] Active character selected id=%s.",
            tostring(result and result.active_character_id or nil)
        )

        if self.character_service:GetActiveCharacterRow(platform_id) ~= nil then
            Console.Log("[gr_characters][server] Active character stored for player.")
        end
    end)

    if not is_started then
        if self.session_state ~= nil then
            self.session_state:SetFailed(platform_id, error)
        end

        Console.Log(
            "[gr_characters][server] Active character selection dispatch failed for platform_id=%s with error=%s.",
            tostring(platform_id),
            tostring(error)
        )
    end
end

function CharacterFlowService:HandleMissingCharacters(platform_id)
    local loaded_player_row = nil

    if self.player_service ~= nil then
        loaded_player_row = self.player_service:GetLoadedPlayerRow(platform_id)
    end

    if self.session_state ~= nil then
        self.session_state:SetPendingCharacterCreation(
            platform_id,
            loaded_player_row and loaded_player_row.id or nil
        )
    end

    Console.Log("[gr_characters][server] No active character selected. Character creation UI will be required later.")

    if self.dev_tool == nil or not self.dev_tool:IsEnabled() then
        return
    end

    Console.Log(
        "[gr_characters][server][dev] Character dev fallback enabled for platform_id=%s.",
        tostring(platform_id)
    )

    self.dev_tool:CreateTestCharacter(platform_id)
end

function CharacterFlowService:LoadCharacters(platform_id)
    local is_started, error = self.character_service:GetCharactersForPlayer(platform_id, function(is_success, selection_state)
        if not is_success then
            if self.session_state ~= nil then
                self.session_state:SetFailed(
                    platform_id,
                    selection_state and selection_state.code or "character-list-load-failed"
                )
            end

            Console.Log(
                "[gr_characters][server] Character list load failed for platform_id=%s with code=%s.",
                tostring(platform_id),
                tostring(selection_state and selection_state.code or "character-list-load-failed")
            )

            return
        end

        local character_count = resolve_character_count(selection_state)

        Console.Log(
            "[gr_characters][server] Characters found count=%s.",
            tostring(character_count)
        )

        if character_count < 1 then
            self:HandleMissingCharacters(platform_id)
            return
        end

        self:SelectFirstCharacter(platform_id, selection_state)
    end)

    if not is_started then
        if self.session_state ~= nil then
            self.session_state:SetFailed(platform_id, error)
        end

        Console.Log(
            "[gr_characters][server] Character list dispatch failed for platform_id=%s with error=%s.",
            tostring(platform_id),
            tostring(error)
        )
    end
end

function CharacterFlowService:CreatePlayerAndContinue(platform_id, observed_username)
    local is_started, error = self.player_service:CreatePlayerRowByPlatformId(platform_id, observed_username, function(is_success, created_state)
        if not is_success then
            if self.session_state ~= nil then
                self.session_state:SetFailed(
                    platform_id,
                    created_state and created_state.error or "player-create-failed"
                )
            end

            Console.Log(
                "[gr_characters][server] Player DB creation failed for platform_id=%s with error=%s.",
                tostring(platform_id),
                tostring(created_state and created_state.error or "player-create-failed")
            )

            return
        end

        Console.Log(
            "[gr_characters][server] Player DB created id=%s.",
            tostring(created_state and created_state.player_id or nil)
        )

        self:LoadCharacters(platform_id)
    end)

    if not is_started then
        if self.session_state ~= nil then
            self.session_state:SetFailed(platform_id, error)
        end

        Console.Log(
            "[gr_characters][server] Player DB creation dispatch failed for platform_id=%s with error=%s.",
            tostring(platform_id),
            tostring(error)
        )
    end
end

function CharacterFlowService:LoadOrCreatePlayer(platform_id, observed_username)
    local is_started, error = self.player_service:LoadPlayerSessionByPlatformId(platform_id, observed_username, function(is_success, player_state)
        if not is_success then
            if self.session_state ~= nil then
                self.session_state:SetFailed(
                    platform_id,
                    player_state and player_state.error or "player-load-failed"
                )
            end

            Console.Log(
                "[gr_characters][server] Player DB load failed for platform_id=%s with error=%s.",
                tostring(platform_id),
                tostring(player_state and player_state.error or "player-load-failed")
            )

            return
        end

        if type(player_state) ~= "table" then
            if self.session_state ~= nil then
                self.session_state:SetFailed(platform_id, "player-state-invalid")
            end

            Console.Log(
                "[gr_characters][server] Player DB load returned an invalid state for platform_id=%s.",
                tostring(platform_id)
            )

            return
        end

        if player_state.status == "player-row-loaded" then
            Console.Log(
                "[gr_characters][server] Player DB loaded id=%s.",
                tostring(player_state.player_id)
            )

            self:LoadCharacters(platform_id)
            return
        end

        if player_state.status == "player-row-missing" then
            self:CreatePlayerAndContinue(platform_id, observed_username)
            return
        end

        Console.Log(
            "[gr_characters][server] Player DB load ended with status=%s for platform_id=%s.",
            tostring(player_state.status),
            tostring(platform_id)
        )

        if self.session_state ~= nil then
            self.session_state:SetFailed(platform_id, player_state.status or "player-load-unexpected-status")
        end
    end)

    if not is_started then
        if self.session_state ~= nil then
            self.session_state:SetFailed(platform_id, error)
        end

        Console.Log(
            "[gr_characters][server] Player DB load dispatch failed for platform_id=%s with error=%s.",
            tostring(platform_id),
            tostring(error)
        )
    end
end

function CharacterFlowService:ProcessConnectedPlayer(player, source_label)
    if self.player_service == nil or self.character_service == nil then
        Console.Log("[gr_characters][server] Character player flow is unavailable because required services are missing.")
        return false, "character-flow-services-missing"
    end

    if source_label == "player-ready" then
        Console.Log("[gr_characters][server] Player connected.")
    else
        Console.Log(
            "[gr_characters][server] Reconciling connected player from source=%s.",
            tostring(source_label or "unknown")
        )
    end

    local is_platform_id_resolved, platform_id_or_error = self.player_service:ResolvePlayerPlatformId(player)

    if not is_platform_id_resolved then
        Console.Log("[gr_characters][server] Unable to resolve platform_id for connected player.")
        Console.Log("[gr_characters][server] Character flow skipped for this player.")
        return true, platform_id_or_error
    end

    local platform_id = platform_id_or_error
    local observed_username = self:ResolveObservedUsername(player, platform_id)

    if self.session_state ~= nil then
        self.session_state:SetLoading(platform_id)
    end

    Console.Log(
        "[gr_characters][server] Resolved platform_id=%s.",
        tostring(platform_id)
    )

    self:LoadOrCreatePlayer(platform_id, observed_username)

    return true
end

GRCharacters.Server.CharacterFlowServiceClass = CharacterFlowService

return CharacterFlowService

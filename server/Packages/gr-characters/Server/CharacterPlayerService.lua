GRCharacters = GRCharacters or {}
GRCharacters.Server = GRCharacters.Server or {}

local CharacterPlayerService = {}
CharacterPlayerService.__index = CharacterPlayerService

local function normalize_player_reference(player_or_platform_id)
    if type(player_or_platform_id) == "string" then
        return player_or_platform_id
    end

    if type(player_or_platform_id) ~= "table" and type(player_or_platform_id) ~= "userdata" then
        return nil
    end

    -- Verified against local nanos world API metadata:
    -- external/nanos-world-docs/src/api/Classes/Player.json
    if type(player_or_platform_id.GetAccountID) == "function" then
        return player_or_platform_id:GetAccountID()
    end

    return nil
end

local function clone_table(source)
    if type(source) ~= "table" then
        return nil
    end

    local copy = {}

    for key, value in pairs(source) do
        copy[key] = value
    end

    return copy
end

function CharacterPlayerService.Create(repository)
    local self = setmetatable({}, CharacterPlayerService)

    self.repository = repository
    self.player_rows_by_platform_id = {}
    self.player_load_states_by_platform_id = {}

    return self
end

function CharacterPlayerService:CacheLoadedPlayerRow(platform_id, observed_username, player_row)
    local loaded_state = {
        status = "player-row-loaded",
        platform_id = platform_id,
        observed_username = observed_username,
        player_id = player_row.id,
        is_banned = player_row.is_banned,
    }

    self.player_rows_by_platform_id[platform_id] = clone_table(player_row)
    self:SetPlayerLoadState(platform_id, loaded_state)

    return loaded_state
end

function CharacterPlayerService:ResolvePlayerPlatformId(player)
    if type(player) ~= "table" and type(player) ~= "userdata" then
        return false, "player-required"
    end

    -- TODO(issue-23): keep this function isolated so the platform identifier
    -- strategy can be changed in one place if server policy evolves.
    if type(player.GetAccountID) ~= "function" then
        return false, "player-get-account-id-unavailable"
    end

    local platform_id = player:GetAccountID()

    if type(platform_id) ~= "string" or platform_id == "" then
        return false, "player-platform-id-unavailable"
    end

    return true, platform_id
end

function CharacterPlayerService:ResolveObservedUsername(player)
    if type(player) ~= "table" and type(player) ~= "userdata" then
        return false, "player-required"
    end

    if type(player.GetName) ~= "function" then
        return false, "player-get-name-unavailable"
    end

    local observed_username = player:GetName()

    if type(observed_username) ~= "string" or observed_username == "" then
        return false, "player-name-unavailable"
    end

    return true, observed_username
end

function CharacterPlayerService:SetPlayerLoadState(platform_id, state)
    self.player_load_states_by_platform_id[platform_id] = clone_table(state)
end

function CharacterPlayerService:GetPlayerLoadState(player_or_platform_id)
    local platform_id = normalize_player_reference(player_or_platform_id)

    if platform_id == nil then
        return nil
    end

    return clone_table(self.player_load_states_by_platform_id[platform_id])
end

function CharacterPlayerService:GetLoadedPlayerRow(player_or_platform_id)
    local platform_id = normalize_player_reference(player_or_platform_id)

    if platform_id == nil then
        return nil
    end

    return clone_table(self.player_rows_by_platform_id[platform_id])
end

function CharacterPlayerService:ForgetPlayerSession(player_or_platform_id)
    local platform_id = normalize_player_reference(player_or_platform_id)

    if platform_id == nil then
        return false, "platform-id-required"
    end

    self.player_rows_by_platform_id[platform_id] = nil
    self.player_load_states_by_platform_id[platform_id] = nil

    Console.Log(
        "[gr_characters][player-service] Cleared player loading session for platform_id=%s.",
        tostring(platform_id)
    )

    return true
end

function CharacterPlayerService:LoadPlayerSession(player, callback)
    local is_platform_id_resolved, platform_id_or_error = self:ResolvePlayerPlatformId(player)

    if not is_platform_id_resolved then
        return false, platform_id_or_error
    end

    local is_username_resolved, observed_username_or_error = self:ResolveObservedUsername(player)

    if not is_username_resolved then
        return false, observed_username_or_error
    end

    return self:LoadPlayerSessionByPlatformId(platform_id_or_error, observed_username_or_error, callback)
end

function CharacterPlayerService:LoadPlayerSessionByPlatformId(platform_id, observed_username, callback)
    if type(platform_id) ~= "string" or platform_id == "" then
        return false, "platform-id-required"
    end

    if type(observed_username) ~= "string" or observed_username == "" then
        return false, "observed-username-required"
    end

    self:SetPlayerLoadState(platform_id, {
        status = "resolving_player",
        platform_id = platform_id,
        observed_username = observed_username,
    })

    Console.Log(
        "[gr_characters][player-service] Resolving players row for platform_id=%s username=%s.",
        tostring(platform_id),
        tostring(observed_username)
    )

    local dispatched, dispatch_error = self.repository:FindPlayerByPlatformId(platform_id, function(is_success, player_row, error)
        if not is_success then
            local blocked_state = {
                status = "blocked",
                platform_id = platform_id,
                observed_username = observed_username,
                error = error,
            }

            self:SetPlayerLoadState(platform_id, blocked_state)

            if type(callback) == "function" then
                callback(false, clone_table(blocked_state))
            end

            return
        end

        if player_row == nil then
            local missing_state = {
                status = "player-row-missing",
                platform_id = platform_id,
                observed_username = observed_username,
                next_action = "create-player-row",
                implementation = "available",
            }

            self.player_rows_by_platform_id[platform_id] = nil
            self:SetPlayerLoadState(platform_id, missing_state)

            Console.Log(
                "[gr_characters][player-service] No players row currently exists for platform_id=%s. Server-side player bootstrap can create it if needed.",
                tostring(platform_id)
            )

            if type(callback) == "function" then
                callback(true, clone_table(missing_state))
            end

            return
        end

        local loaded_state = self:CacheLoadedPlayerRow(platform_id, observed_username, player_row)

        Console.Log(
            "[gr_characters][player-service] Player session loaded for platform_id=%s player_id=%s.",
            tostring(platform_id),
            tostring(player_row.id)
        )

        if type(callback) == "function" then
            callback(true, clone_table(loaded_state))
        end
    end)

    if not dispatched then
        return false, dispatch_error
    end

    return true
end

function CharacterPlayerService:CreatePlayerRowByPlatformId(platform_id, observed_username, callback)
    if type(platform_id) ~= "string" or platform_id == "" then
        return false, "platform-id-required"
    end

    if type(observed_username) ~= "string" or observed_username == "" then
        return false, "observed-username-required"
    end

    if self.repository == nil then
        return false, "player-repository-missing"
    end

    Console.Log(
        "[gr_characters][player-service] Creating players row for platform_id=%s username=%s through server-side bootstrap.",
        tostring(platform_id),
        tostring(observed_username)
    )

    local dispatched, dispatch_error = self.repository:InsertPlayer(platform_id, observed_username, function(is_success, player_row, error)
        if not is_success or player_row == nil then
            local blocked_state = {
                status = "blocked",
                platform_id = platform_id,
                observed_username = observed_username,
                error = error or "player-create-failed",
            }

            self.player_rows_by_platform_id[platform_id] = nil
            self:SetPlayerLoadState(platform_id, blocked_state)

            if type(callback) == "function" then
                callback(false, clone_table(blocked_state))
            end

            return
        end

        local loaded_state = self:CacheLoadedPlayerRow(platform_id, observed_username, player_row)

        if type(callback) == "function" then
            callback(true, clone_table(loaded_state))
        end
    end)

    if not dispatched then
        return false, dispatch_error
    end

    return true
end

GRCharacters.Server.CharacterPlayerServiceClass = CharacterPlayerService

return CharacterPlayerService

GRCharacters = GRCharacters or {}
GRCharacters.Server = GRCharacters.Server or {}

local CharacterSessionState = {}
CharacterSessionState.__index = CharacterSessionState

local STATUS_LOADING = "loading"
local STATUS_ACTIVE_CHARACTER_SELECTED = "active-character-selected"
local STATUS_PENDING_CHARACTER_CREATION = "pending-character-creation"
local STATUS_FAILED = "failed"

local function normalize_platform_id(platform_id)
    if type(platform_id) == "table" or type(platform_id) == "userdata" then
        if type(platform_id.GetAccountID) == "function" then
            return normalize_platform_id(platform_id:GetAccountID())
        end

        return normalize_platform_id(platform_id.platform_id)
    end

    if type(platform_id) ~= "string" then
        return nil
    end

    if platform_id == "" then
        return nil
    end

    return platform_id
end

local function clone_table(source)
    if type(source) ~= "table" then
        return nil
    end

    local copy = {}

    for key, value in pairs(source) do
        if type(value) == "table" then
            copy[key] = clone_table(value)
        else
            copy[key] = value
        end
    end

    return copy
end

local function resolve_character_id(active_character)
    if type(active_character) ~= "table" then
        return nil
    end

    return active_character.id
end

function CharacterSessionState.Create()
    local self = setmetatable({}, CharacterSessionState)

    self.sessions_by_platform_id = {}

    return self
end

function CharacterSessionState:SetLoading(platform_id)
    local normalized_platform_id = normalize_platform_id(platform_id)

    if normalized_platform_id == nil then
        return false, "platform-id-required"
    end

    self.sessions_by_platform_id[normalized_platform_id] = {
        status = STATUS_LOADING,
        platform_id = normalized_platform_id,
    }

    Console.Log(
        "[gr_characters][session-state] Session loading for platform_id=%s.",
        tostring(normalized_platform_id)
    )

    return true
end

function CharacterSessionState:SetPendingCharacterCreation(platform_id, player_id)
    local normalized_platform_id = normalize_platform_id(platform_id)

    if normalized_platform_id == nil then
        return false, "platform-id-required"
    end

    self.sessions_by_platform_id[normalized_platform_id] = {
        status = STATUS_PENDING_CHARACTER_CREATION,
        platform_id = normalized_platform_id,
        player_id = player_id,
    }

    Console.Log(
        "[gr_characters][session-state] Pending character creation for platform_id=%s player_id=%s.",
        tostring(normalized_platform_id),
        tostring(player_id)
    )

    return true
end

function CharacterSessionState:SetActiveCharacter(platform_id, player_id, active_character)
    local normalized_platform_id = normalize_platform_id(platform_id)

    if normalized_platform_id == nil then
        return false, "platform-id-required"
    end

    if type(active_character) ~= "table" then
        return false, "active-character-required"
    end

    local active_character_id = resolve_character_id(active_character)

    self.sessions_by_platform_id[normalized_platform_id] = {
        status = STATUS_ACTIVE_CHARACTER_SELECTED,
        platform_id = normalized_platform_id,
        player_id = player_id,
        active_character_id = active_character_id,
        active_character = clone_table(active_character),
    }

    Console.Log(
        "[gr_characters][session-state] status=%s platform_id=%s player_id=%s character_id=%s.",
        STATUS_ACTIVE_CHARACTER_SELECTED,
        tostring(normalized_platform_id),
        tostring(player_id),
        tostring(active_character_id)
    )

    return true
end

function CharacterSessionState:SetFailed(platform_id, error)
    local normalized_platform_id = normalize_platform_id(platform_id)

    if normalized_platform_id == nil then
        return false, "platform-id-required"
    end

    self.sessions_by_platform_id[normalized_platform_id] = {
        status = STATUS_FAILED,
        platform_id = normalized_platform_id,
        error = error,
    }

    Console.Log(
        "[gr_characters][session-state] Session failed for platform_id=%s error=%s.",
        tostring(normalized_platform_id),
        tostring(error)
    )

    return true
end

function CharacterSessionState:GetSession(platform_id)
    local normalized_platform_id = normalize_platform_id(platform_id)

    if normalized_platform_id == nil then
        return nil
    end

    return clone_table(self.sessions_by_platform_id[normalized_platform_id])
end

function CharacterSessionState:GetStatus(platform_id)
    local session = self:GetSession(platform_id)

    if session == nil then
        return nil
    end

    return session.status
end

function CharacterSessionState:GetActiveCharacter(platform_id)
    local session = self:GetSession(platform_id)

    if session == nil or session.status ~= STATUS_ACTIVE_CHARACTER_SELECTED then
        return nil
    end

    return clone_table(session.active_character)
end

function CharacterSessionState:HasActiveCharacter(platform_id)
    return self:GetActiveCharacter(platform_id) ~= nil
end

function CharacterSessionState:IsGameplayReady(platform_id)
    local status = self:GetStatus(platform_id)

    if status == nil then
        return false, "session-missing"
    end

    if status ~= STATUS_ACTIVE_CHARACTER_SELECTED then
        return false, status
    end

    if not self:HasActiveCharacter(platform_id) then
        return false, "active-character-missing"
    end

    return true, STATUS_ACTIVE_CHARACTER_SELECTED
end

function CharacterSessionState:Clear(platform_id)
    local normalized_platform_id = normalize_platform_id(platform_id)

    if normalized_platform_id == nil then
        return false, "platform-id-required"
    end

    self.sessions_by_platform_id[normalized_platform_id] = nil

    Console.Log(
        "[gr_characters][session-state] Session cleared for platform_id=%s.",
        tostring(normalized_platform_id)
    )

    return true
end

GRCharacters.Server.CharacterSessionStateClass = CharacterSessionState

return CharacterSessionState

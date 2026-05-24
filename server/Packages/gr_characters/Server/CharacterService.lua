GRCharacters = GRCharacters or {}
GRCharacters.Server = GRCharacters.Server or {}

local CharacterService = {}
CharacterService.__index = CharacterService

local function normalize_player_id(player_or_id)
    if type(player_or_id) == "string" then
        return player_or_id
    end

    if type(player_or_id) == "number" then
        return tostring(player_or_id)
    end

    if type(player_or_id) ~= "table" and type(player_or_id) ~= "userdata" then
        return nil
    end

    -- Future integration can standardize this through gr_core. For now the
    -- scaffold accepts either an explicit id or a player-like object.
    if type(player_or_id.GetAccountIDString) == "function" then
        return player_or_id:GetAccountIDString()
    end

    if type(player_or_id.GetSteamIDString) == "function" then
        return player_or_id:GetSteamIDString()
    end

    if type(player_or_id.GetID) == "function" then
        return tostring(player_or_id:GetID())
    end

    if type(player_or_id.id) == "string" or type(player_or_id.id) == "number" then
        return tostring(player_or_id.id)
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

function CharacterService.Create(repository)
    local self = setmetatable({}, CharacterService)

    self.repository = repository
    self.active_character_ids_by_player_id = {}

    return self
end

function CharacterService:GetCharactersForPlayer(player_or_id)
    local player_id = normalize_player_id(player_or_id)

    if player_id == nil then
        return false, "player-id-required"
    end

    Console.Log("[gr_characters][service] Listing characters for player_id=%s.", tostring(player_id))

    return self.repository:GetCharactersByPlayerId(player_id)
end

function CharacterService:CreateCharacter(player_or_id, character_payload)
    local player_id = normalize_player_id(player_or_id)

    if player_id == nil then
        return false, "player-id-required"
    end

    if type(character_payload) ~= "table" then
        return false, "character-payload-required"
    end

    -- Future server-side validation will check naming, faction eligibility,
    -- default money, spawn policy and all persistence rules before insert.
    Console.Log("[gr_characters][service] Character creation requested for player_id=%s.", tostring(player_id))

    return self.repository:InsertCharacter(player_id, character_payload)
end

function CharacterService:SelectActiveCharacter(player_or_id, character_id)
    local player_id = normalize_player_id(player_or_id)

    if player_id == nil then
        return false, "player-id-required"
    end

    if character_id == nil then
        return false, "character-id-required"
    end

    Console.Log(
        "[gr_characters][service] Active character selection requested for player_id=%s character_id=%s.",
        tostring(player_id),
        tostring(character_id)
    )

    local is_success, result = self.repository:SetActiveCharacter(player_id, character_id)

    if is_success then
        self.active_character_ids_by_player_id[player_id] = character_id
    end

    return is_success, result
end

function CharacterService:SaveActiveCharacterPosition(player_or_id, position)
    local player_id = normalize_player_id(player_or_id)

    if player_id == nil then
        return false, "player-id-required"
    end

    local normalized_position = normalize_position(position)

    if normalized_position == nil then
        return false, "position-required"
    end

    local character_id = self.active_character_ids_by_player_id[player_id]

    if character_id == nil then
        return false, "active-character-required"
    end

    Console.Log(
        "[gr_characters][service] Position save requested for player_id=%s character_id=%s.",
        tostring(player_id),
        tostring(character_id)
    )

    return self.repository:SaveCharacterPosition(character_id, normalized_position)
end

function CharacterService:GetActiveCharacterId(player_or_id)
    local player_id = normalize_player_id(player_or_id)

    if player_id == nil then
        return nil
    end

    return self.active_character_ids_by_player_id[player_id]
end

GRCharacters.Server.CharacterServiceClass = CharacterService

return CharacterService

GRCharacters = GRCharacters or {}
GRCharacters.Server = GRCharacters.Server or {}

local CharacterRepository = {}
CharacterRepository.__index = CharacterRepository

function CharacterRepository.Create(database_service)
    local self = setmetatable({}, CharacterRepository)

    self.database_service = database_service

    return self
end

function CharacterRepository:GetCharactersByPlayerId(player_id)
    Console.Log(
        "[gr_characters][repository] Character load requested for player_id=%s. Repository stub active; no query executed.",
        tostring(player_id)
    )

    return false, "not-implemented"
end

function CharacterRepository:InsertCharacter(player_id, character_payload)
    Console.Log(
        "[gr_characters][repository] Character creation requested for player_id=%s. Repository stub active; no insert executed.",
        tostring(player_id)
    )

    return false, "not-implemented"
end

function CharacterRepository:SetActiveCharacter(player_id, character_id)
    Console.Log(
        "[gr_characters][repository] Active character selection requested for player_id=%s character_id=%s. Repository stub active; no update executed.",
        tostring(player_id),
        tostring(character_id)
    )

    return false, "not-implemented"
end

function CharacterRepository:SaveCharacterPosition(character_id, position)
    Console.Log(
        "[gr_characters][repository] Position save requested for character_id=%s. Repository stub active; no update executed.",
        tostring(character_id)
    )

    return false, "not-implemented"
end

GRCharacters.Server.CharacterRepositoryClass = CharacterRepository

return CharacterRepository

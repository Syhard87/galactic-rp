GRCharacters = GRCharacters or {}
GRCharacters.Server = GRCharacters.Server or {}

local CharacterRepository = {}
CharacterRepository.__index = CharacterRepository

local INSERT_CHARACTER_QUERY = [[
    INSERT INTO characters (
        player_id,
        first_name,
        last_name,
        age,
        species,
        biography
    )
    VALUES (
        :0,
        :1,
        :2,
        :3,
        :4,
        :5
    )
]]

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

function CharacterRepository:InsertCharacter(player_id, character_payload, callback)
    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if type(player_id) ~= "number" and type(player_id) ~= "string" then
        callback(false, "player-id-required")
        return true
    end

    if type(character_payload) ~= "table" then
        callback(false, "character-payload-required")
        return true
    end

    if self.database_service == nil then
        Console.Log(
            "[gr_characters][repository] Character creation requested for player_id=%s but database service is unavailable.",
            tostring(player_id)
        )

        callback(false, "database-service-missing")
        return true
    end

    local is_connected, database_or_error = self.database_service:Connect()

    if not is_connected then
        Console.Log(
            "[gr_characters][repository] Database connection failed during character creation for player_id=%s with error=%s.",
            tostring(player_id),
            tostring(database_or_error)
        )

        callback(false, database_or_error)
        return true
    end

    Console.Log(
        "[gr_characters][repository] Inserting character row for player_id=%s with server-controlled defaults.",
        tostring(player_id)
    )

    database_or_error:ExecuteAsync(
        INSERT_CHARACTER_QUERY,
        function(rows_affected, error)
            if error ~= nil then
                Console.Log(
                    "[gr_characters][repository] Character insert failed for player_id=%s with error=%s.",
                    tostring(player_id),
                    tostring(error)
                )

                callback(false, error)
                return
            end

            if rows_affected ~= 1 then
                Console.Log(
                    "[gr_characters][repository] Character insert for player_id=%s returned unexpected rows_affected=%s.",
                    tostring(player_id),
                    tostring(rows_affected)
                )

                callback(false, "character-insert-unexpected-rows-affected")
                return
            end

            callback(true, {
                rows_affected = rows_affected,
            })
        end,
        player_id,
        character_payload.first_name,
        character_payload.last_name,
        character_payload.age,
        character_payload.species,
        character_payload.biography
    )

    return true
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

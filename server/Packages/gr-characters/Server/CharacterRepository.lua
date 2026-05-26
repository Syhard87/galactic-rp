GRCharacters = GRCharacters or {}
GRCharacters.Server = GRCharacters.Server or {}

local CharacterRepository = {}
CharacterRepository.__index = CharacterRepository

local SELECT_CHARACTERS_BY_PLAYER_ID_QUERY = [[
    SELECT
        id,
        player_id,
        first_name,
        last_name,
        age,
        species,
        biography,
        created_at,
        updated_at
    FROM characters
    WHERE player_id = :0
    ORDER BY created_at ASC, id ASC
]]

local SELECT_CHARACTER_BY_ID_QUERY = [[
    SELECT
        id,
        player_id,
        first_name,
        last_name,
        age,
        species,
        biography,
        position_x,
        position_y,
        position_z,
        created_at,
        updated_at
    FROM characters
    WHERE id = :0
    LIMIT 1
]]

local UPDATE_CHARACTER_POSITION_QUERY = [[
    UPDATE characters
    SET
        position_x = :1,
        position_y = :2,
        position_z = :3,
        updated_at = NOW()
    WHERE id = :0
]]

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

local function normalize_character_row(row)
    if type(row) ~= "table" then
        return nil
    end

    return {
        id = row.id,
        player_id = row.player_id,
        first_name = row.first_name,
        last_name = row.last_name,
        age = row.age,
        species = row.species,
        biography = row.biography,
        position_x = row.position_x,
        position_y = row.position_y,
        position_z = row.position_z,
        created_at = row.created_at,
        updated_at = row.updated_at,
    }
end

function CharacterRepository.Create(database_service)
    local self = setmetatable({}, CharacterRepository)

    self.database_service = database_service

    return self
end

function CharacterRepository:GetCharactersByPlayerId(player_id, callback)
    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if type(player_id) ~= "number" and type(player_id) ~= "string" then
        callback(false, nil, "player-id-required")
        return true
    end

    if self.database_service == nil then
        Console.Log(
            "[gr_characters][repository] Character list requested for player_id=%s but database service is unavailable.",
            tostring(player_id)
        )

        callback(false, nil, "database-service-missing")
        return true
    end

    local is_connected, database_or_error = self.database_service:Connect()

    if not is_connected then
        Console.Log(
            "[gr_characters][repository] Database connection failed during character list loading for player_id=%s with error=%s.",
            tostring(player_id),
            tostring(database_or_error)
        )

        callback(false, nil, database_or_error)
        return true
    end

    Console.Log(
        "[gr_characters][repository] Loading characters for player_id=%s.",
        tostring(player_id)
    )

    database_or_error:SelectAsync(SELECT_CHARACTERS_BY_PLAYER_ID_QUERY, function(rows, error)
        if error ~= nil then
            Console.Log(
                "[gr_characters][repository] Character list load failed for player_id=%s with error=%s.",
                tostring(player_id),
                tostring(error)
            )

            callback(false, nil, error)
            return
        end

        local normalized_rows = {}

        if type(rows) == "table" then
            for _, row in ipairs(rows) do
                local normalized_row = normalize_character_row(row)

                if normalized_row ~= nil then
                    normalized_rows[#normalized_rows + 1] = normalized_row
                end
            end
        end

        Console.Log(
            "[gr_characters][repository] Loaded %s characters for player_id=%s.",
            tostring(#normalized_rows),
            tostring(player_id)
        )

        callback(true, normalized_rows, nil)
    end, player_id)

    return true
end

function CharacterRepository:FindCharacterById(character_id, callback)
    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if type(character_id) ~= "number" and type(character_id) ~= "string" then
        callback(false, nil, "character-id-required")
        return true
    end

    if self.database_service == nil then
        Console.Log(
            "[gr_characters][repository] Character lookup requested for character_id=%s but database service is unavailable.",
            tostring(character_id)
        )

        callback(false, nil, "database-service-missing")
        return true
    end

    local is_connected, database_or_error = self.database_service:Connect()

    if not is_connected then
        Console.Log(
            "[gr_characters][repository] Database connection failed during character lookup for character_id=%s with error=%s.",
            tostring(character_id),
            tostring(database_or_error)
        )

        callback(false, nil, database_or_error)
        return true
    end

    Console.Log(
        "[gr_characters][repository] Loading character_id=%s for server-side selection validation.",
        tostring(character_id)
    )

    database_or_error:SelectAsync(SELECT_CHARACTER_BY_ID_QUERY, function(rows, error)
        if error ~= nil then
            Console.Log(
                "[gr_characters][repository] Character lookup failed for character_id=%s with error=%s.",
                tostring(character_id),
                tostring(error)
            )

            callback(false, nil, error)
            return
        end

        if type(rows) ~= "table" or rows[1] == nil then
            Console.Log(
                "[gr_characters][repository] No character row found for character_id=%s.",
                tostring(character_id)
            )

            callback(true, nil, nil)
            return
        end

        local normalized_row = normalize_character_row(rows[1])

        callback(true, normalized_row, nil)
    end, character_id)

    return true
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
        "[gr_characters][repository] Active character persistence requested for player_id=%s character_id=%s, but selection remains session-only in the MVP schema.",
        tostring(player_id),
        tostring(character_id)
    )

    return false, "not-implemented"
end

function CharacterRepository:UpdateCharacterPosition(character_id, position, callback)
    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if type(character_id) ~= "number" and type(character_id) ~= "string" then
        callback(false, "character-id-required")
        return true
    end

    if type(position) ~= "table"
        or type(position.x) ~= "number"
        or type(position.y) ~= "number"
        or type(position.z) ~= "number"
    then
        callback(false, "position-required")
        return true
    end

    if self.database_service == nil then
        Console.Log(
            "[gr_characters][repository] Position update requested for character_id=%s but database service is unavailable.",
            tostring(character_id)
        )

        callback(false, "database-service-missing")
        return true
    end

    local is_connected, database_or_error = self.database_service:Connect()

    if not is_connected then
        Console.Log(
            "[gr_characters][repository] Database connection failed during position save for character_id=%s with error=%s.",
            tostring(character_id),
            tostring(database_or_error)
        )

        callback(false, database_or_error)
        return true
    end

    database_or_error:ExecuteAsync(
        UPDATE_CHARACTER_POSITION_QUERY,
        function(rows_affected, error)
            if error ~= nil then
                Console.Log(
                    "[gr_characters][repository] Position update failed for character_id=%s with error=%s.",
                    tostring(character_id),
                    tostring(error)
                )

                callback(false, error)
                return
            end

            if rows_affected ~= 1 then
                Console.Log(
                    "[gr_characters][repository] Position update for character_id=%s returned unexpected rows_affected=%s.",
                    tostring(character_id),
                    tostring(rows_affected)
                )

                callback(false, "character-position-update-unexpected-rows-affected")
                return
            end

            callback(true, {
                rows_affected = rows_affected,
            })
        end,
        character_id,
        position.x,
        position.y,
        position.z
    )

    return true
end

GRCharacters.Server.CharacterRepositoryClass = CharacterRepository

return CharacterRepository

GRCharacters = GRCharacters or {}
GRCharacters.Server = GRCharacters.Server or {}

local CharacterPlayerRepository = {}
CharacterPlayerRepository.__index = CharacterPlayerRepository

local SELECT_PLAYER_BY_PLATFORM_ID_QUERY = [[
    SELECT
        id,
        platform_id,
        username,
        first_join_at,
        last_join_at,
        is_banned,
        ban_reason,
        created_at,
        updated_at
    FROM players
    WHERE platform_id = :0
    LIMIT 1
]]

local function normalize_player_row(row)
    if type(row) ~= "table" then
        return nil
    end

    return {
        id = row.id,
        platform_id = row.platform_id,
        username = row.username,
        first_join_at = row.first_join_at,
        last_join_at = row.last_join_at,
        is_banned = row.is_banned,
        ban_reason = row.ban_reason,
        created_at = row.created_at,
        updated_at = row.updated_at,
    }
end

function CharacterPlayerRepository.Create(database_service)
    local self = setmetatable({}, CharacterPlayerRepository)

    self.database_service = database_service

    return self
end

function CharacterPlayerRepository:FindPlayerByPlatformId(platform_id, callback)
    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if type(platform_id) ~= "string" or platform_id == "" then
        callback(false, nil, "platform-id-required")
        return true
    end

    if self.database_service == nil then
        Console.Log(
            "[gr_characters][player-repository] Player lookup requested for platform_id=%s but database service is unavailable.",
            tostring(platform_id)
        )

        callback(false, nil, "database-service-missing")
        return true
    end

    local is_success, database_or_error = self.database_service:Connect()

    if not is_success then
        Console.Log(
            "[gr_characters][player-repository] Database connection failed for platform_id=%s with error=%s.",
            tostring(platform_id),
            tostring(database_or_error)
        )

        callback(false, nil, database_or_error)
        return true
    end

    Console.Log(
        "[gr_characters][player-repository] Looking up players.platform_id=%s.",
        tostring(platform_id)
    )

    database_or_error:SelectAsync(SELECT_PLAYER_BY_PLATFORM_ID_QUERY, function(rows, error)
        if error ~= nil then
            Console.Log(
                "[gr_characters][player-repository] Player lookup failed for platform_id=%s with error=%s.",
                tostring(platform_id),
                tostring(error)
            )

            callback(false, nil, error)
            return
        end

        if type(rows) ~= "table" or rows[1] == nil then
            Console.Log(
                "[gr_characters][player-repository] No players row found for platform_id=%s.",
                tostring(platform_id)
            )

            callback(true, nil, nil)
            return
        end

        local normalized_row = normalize_player_row(rows[1])

        Console.Log(
            "[gr_characters][player-repository] Loaded players row id=%s for platform_id=%s.",
            tostring(normalized_row.id),
            tostring(platform_id)
        )

        callback(true, normalized_row, nil)
    end, platform_id)

    return true
end

function CharacterPlayerRepository:InsertPlayer(platform_id, username)
    Console.Log(
        "[gr_characters][player-repository] Player creation prepared for platform_id=%s username=%s. Insert path intentionally not implemented in issue #23.",
        tostring(platform_id),
        tostring(username)
    )

    return false, "not-implemented"
end

GRCharacters.Server.CharacterPlayerRepositoryClass = CharacterPlayerRepository

return CharacterPlayerRepository

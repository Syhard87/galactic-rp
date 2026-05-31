GRFactions = GRFactions or {}
GRFactions.Server = GRFactions.Server or {}

local FactionRepository = {}
FactionRepository.__index = FactionRepository

local SELECT_FACTIONS_QUERY = [[
    SELECT
        id,
        name,
        type,
        description,
        is_whitelisted,
        created_at,
        updated_at
    FROM factions
    ORDER BY name ASC, id ASC
]]

local SELECT_FACTION_BY_ID_QUERY = [[
    SELECT
        id,
        name,
        type,
        description,
        is_whitelisted,
        created_at,
        updated_at
    FROM factions
    WHERE id = :0
    LIMIT 1
]]

local SELECT_RANKS_QUERY = [[
    SELECT
        id,
        faction_id,
        name,
        level,
        permissions_json,
        created_at,
        updated_at
    FROM faction_ranks
    ORDER BY faction_id ASC, level ASC, id ASC
]]

local SELECT_RANKS_BY_FACTION_ID_QUERY = [[
    SELECT
        id,
        faction_id,
        name,
        level,
        permissions_json,
        created_at,
        updated_at
    FROM faction_ranks
    WHERE faction_id = :0
    ORDER BY level ASC, id ASC
]]

local SELECT_RANK_BY_ID_QUERY = [[
    SELECT
        id,
        faction_id,
        name,
        level,
        permissions_json,
        created_at,
        updated_at
    FROM faction_ranks
    WHERE id = :0
    LIMIT 1
]]

local SELECT_CHARACTER_AFFILIATION_BY_ID_QUERY = [[
    SELECT
        id,
        faction_id,
        rank_id
    FROM characters
    WHERE id = :0
    LIMIT 1
]]

local UPDATE_CHARACTER_AFFILIATION_QUERY = [[
    UPDATE characters
    SET
        faction_id = NULLIF(:1, 0),
        rank_id = NULLIF(:2, 0),
        updated_at = NOW()
    WHERE id = :0
]]

local function normalize_positive_integer(value)
    if type(value) == "number" then
        if value < 1 then
            return nil
        end

        return math.floor(value)
    end

    if type(value) == "string" then
        if value:match("^%d+$") == nil then
            return nil
        end

        local parsed_value = tonumber(value)

        if parsed_value == nil or parsed_value < 1 then
            return nil
        end

        return math.floor(parsed_value)
    end

    return nil
end

local function normalize_faction_row(row)
    local faction_id = nil

    if type(row) ~= "table" then
        return nil
    end

    faction_id = normalize_positive_integer(row.id)

    if faction_id == nil then
        return nil
    end

    return {
        id = faction_id,
        name = row.name,
        type = row.type,
        description = row.description,
        is_whitelisted = row.is_whitelisted == true,
        created_at = row.created_at,
        updated_at = row.updated_at,
    }
end

local function normalize_rank_row(row)
    local rank_id = nil
    local faction_id = nil

    if type(row) ~= "table" then
        return nil
    end

    rank_id = normalize_positive_integer(row.id)
    faction_id = normalize_positive_integer(row.faction_id)

    if rank_id == nil or faction_id == nil then
        return nil
    end

    return {
        id = rank_id,
        faction_id = faction_id,
        name = row.name,
        level = tonumber(row.level) or 0,
        permissions_json = row.permissions_json,
        created_at = row.created_at,
        updated_at = row.updated_at,
    }
end

local function normalize_rows(rows, normalizer)
    local normalized_rows = {}

    if type(rows) ~= "table" then
        return normalized_rows
    end

    for _, row in ipairs(rows) do
        local normalized_row = normalizer(row)

        if normalized_row ~= nil then
            normalized_rows[#normalized_rows + 1] = normalized_row
        end
    end

    return normalized_rows
end

local function normalize_character_affiliation_row(row)
    local character_id = nil

    if type(row) ~= "table" then
        return nil
    end

    character_id = normalize_positive_integer(row.id)

    if character_id == nil then
        return nil
    end

    return {
        id = character_id,
        faction_id = normalize_positive_integer(row.faction_id),
        rank_id = normalize_positive_integer(row.rank_id),
    }
end

function FactionRepository.Create(database_service)
    local self = setmetatable({}, FactionRepository)

    self.database_service = database_service

    return self
end

function FactionRepository:Connect(callback, reason)
    local is_connected = false
    local database_or_error = nil

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if self.database_service == nil then
        Console.Log(
            "[gr_factions][repository] Database service unavailable during %s.",
            tostring(reason or "repository-call")
        )

        callback(false, nil, "database-service-missing")
        return true
    end

    is_connected, database_or_error = self.database_service:Connect()

    if not is_connected then
        Console.Log(
            "[gr_factions][repository] Database connection failed during %s with error=%s.",
            tostring(reason or "repository-call"),
            tostring(database_or_error)
        )

        callback(false, nil, database_or_error)
        return true
    end

    callback(true, database_or_error, nil)
    return true
end

function FactionRepository:ListFactions(callback)
    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    return self:Connect(function(is_connected, database_or_error, error)
        if not is_connected then
            callback(false, nil, error)
            return
        end

        database_or_error:SelectAsync(SELECT_FACTIONS_QUERY, function(rows, select_error)
            if select_error ~= nil then
                Console.Log(
                    "[gr_factions][repository] Factions list load failed with error=%s.",
                    tostring(select_error)
                )

                callback(false, nil, select_error)
                return
            end

            callback(true, normalize_rows(rows, normalize_faction_row), nil)
        end)
    end, "factions-list")
end

function FactionRepository:GetFactionById(faction_id, callback)
    local normalized_faction_id = normalize_positive_integer(faction_id)

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if normalized_faction_id == nil then
        callback(false, nil, "faction-id-required")
        return true
    end

    return self:Connect(function(is_connected, database_or_error, error)
        if not is_connected then
            callback(false, nil, error)
            return
        end

        database_or_error:SelectAsync(SELECT_FACTION_BY_ID_QUERY, function(rows, select_error)
            local normalized_rows = nil

            if select_error ~= nil then
                Console.Log(
                    "[gr_factions][repository] Faction lookup failed for faction_id=%s with error=%s.",
                    tostring(normalized_faction_id),
                    tostring(select_error)
                )

                callback(false, nil, select_error)
                return
            end

            normalized_rows = normalize_rows(rows, normalize_faction_row)
            callback(true, normalized_rows[1], nil)
        end, normalized_faction_id)
    end, "faction-by-id")
end

function FactionRepository:ListRanks(callback)
    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    return self:Connect(function(is_connected, database_or_error, error)
        if not is_connected then
            callback(false, nil, error)
            return
        end

        database_or_error:SelectAsync(SELECT_RANKS_QUERY, function(rows, select_error)
            if select_error ~= nil then
                Console.Log(
                    "[gr_factions][repository] Ranks list load failed with error=%s.",
                    tostring(select_error)
                )

                callback(false, nil, select_error)
                return
            end

            callback(true, normalize_rows(rows, normalize_rank_row), nil)
        end)
    end, "ranks-list")
end

function FactionRepository:ListRanksByFactionId(faction_id, callback)
    local normalized_faction_id = normalize_positive_integer(faction_id)

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if normalized_faction_id == nil then
        callback(false, nil, "faction-id-required")
        return true
    end

    return self:Connect(function(is_connected, database_or_error, error)
        if not is_connected then
            callback(false, nil, error)
            return
        end

        database_or_error:SelectAsync(SELECT_RANKS_BY_FACTION_ID_QUERY, function(rows, select_error)
            if select_error ~= nil then
                Console.Log(
                    "[gr_factions][repository] Faction ranks load failed for faction_id=%s with error=%s.",
                    tostring(normalized_faction_id),
                    tostring(select_error)
                )

                callback(false, nil, select_error)
                return
            end

            callback(true, normalize_rows(rows, normalize_rank_row), nil)
        end, normalized_faction_id)
    end, "ranks-by-faction-id")
end

function FactionRepository:GetRankById(rank_id, callback)
    local normalized_rank_id = normalize_positive_integer(rank_id)

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if normalized_rank_id == nil then
        callback(false, nil, "rank-id-required")
        return true
    end

    return self:Connect(function(is_connected, database_or_error, error)
        if not is_connected then
            callback(false, nil, error)
            return
        end

        database_or_error:SelectAsync(SELECT_RANK_BY_ID_QUERY, function(rows, select_error)
            local normalized_rows = nil

            if select_error ~= nil then
                Console.Log(
                    "[gr_factions][repository] Rank lookup failed for rank_id=%s with error=%s.",
                    tostring(normalized_rank_id),
                    tostring(select_error)
                )

                callback(false, nil, select_error)
                return
            end

            normalized_rows = normalize_rows(rows, normalize_rank_row)
            callback(true, normalized_rows[1], nil)
        end, normalized_rank_id)
    end, "rank-by-id")
end

function FactionRepository:GetCharacterAffiliation(character_id, callback)
    local normalized_character_id = normalize_positive_integer(character_id)

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if normalized_character_id == nil then
        callback(false, nil, "character-id-required")
        return true
    end

    return self:Connect(function(is_connected, database_or_error, error)
        if not is_connected then
            callback(false, nil, error)
            return
        end

        database_or_error:SelectAsync(SELECT_CHARACTER_AFFILIATION_BY_ID_QUERY, function(rows, select_error)
            local normalized_rows = nil

            if select_error ~= nil then
                Console.Log(
                    "[gr_factions][repository] Character affiliation lookup failed for character_id=%s with error=%s.",
                    tostring(normalized_character_id),
                    tostring(select_error)
                )

                callback(false, nil, select_error)
                return
            end

            normalized_rows = normalize_rows(rows, normalize_character_affiliation_row)
            callback(true, normalized_rows[1], nil)
        end, normalized_character_id)
    end, "character-affiliation-by-id")
end

function FactionRepository:AssignCharacterFaction(character_id, faction_id, rank_id, callback)
    local normalized_character_id = normalize_positive_integer(character_id)
    local normalized_faction_id = normalize_positive_integer(faction_id)
    local normalized_rank_id = normalize_positive_integer(rank_id)
    local faction_lookup_id = normalized_faction_id
    local rank_lookup_id = normalized_rank_id

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if normalized_character_id == nil then
        callback(false, nil, "character-id-required")
        return true
    end

    if rank_lookup_id ~= nil and faction_lookup_id == nil then
        callback(false, nil, "faction-id-required-when-rank-is-provided")
        return true
    end

    self:GetCharacterAffiliation(normalized_character_id, function(is_success, character_row, error)
        if not is_success then
            callback(false, nil, error)
            return
        end

        if character_row == nil then
            callback(false, nil, "character-not-found")
            return
        end

        local function persist_assignment()
            self:Connect(function(is_connected, database_or_error, connect_error)
                if not is_connected then
                    callback(false, nil, connect_error)
                    return
                end

                database_or_error:ExecuteAsync(
                    UPDATE_CHARACTER_AFFILIATION_QUERY,
                    function(rows_affected, execute_error)
                        if execute_error ~= nil then
                            Console.Log(
                                "[gr_factions][repository] Character affiliation update failed for character_id=%s with error=%s.",
                                tostring(normalized_character_id),
                                tostring(execute_error)
                            )

                            callback(false, nil, execute_error)
                            return
                        end

                        if rows_affected ~= 1 then
                            callback(false, nil, "character-affiliation-update-unexpected-rows-affected")
                            return
                        end

                        callback(true, {
                            character_id = normalized_character_id,
                            faction_id = faction_lookup_id,
                            rank_id = rank_lookup_id,
                        }, nil)
                    end,
                    normalized_character_id,
                    faction_lookup_id or 0,
                    rank_lookup_id or 0
                )
            end, "assign-character-faction")
        end

        local function validate_rank_or_persist()
            if rank_lookup_id == nil then
                persist_assignment()
                return
            end

            self:GetRankById(rank_lookup_id, function(rank_success, rank_row, rank_error)
                if not rank_success then
                    callback(false, nil, rank_error)
                    return
                end

                if rank_row == nil then
                    callback(false, nil, "rank-not-found")
                    return
                end

                if normalize_positive_integer(rank_row.faction_id) ~= faction_lookup_id then
                    callback(false, nil, "rank-does-not-belong-to-faction")
                    return
                end

                persist_assignment()
            end)
        end

        if faction_lookup_id == nil then
            persist_assignment()
            return
        end

        self:GetFactionById(faction_lookup_id, function(faction_success, faction_row, faction_error)
            if not faction_success then
                callback(false, nil, faction_error)
                return
            end

            if faction_row == nil then
                callback(false, nil, "faction-not-found")
                return
            end

            validate_rank_or_persist()
        end)
    end)

    return true
end

function FactionRepository:ResolveFactionAndRank(character_row, callback)
    local faction_id = nil
    local rank_id = nil
    local resolution = nil

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if type(character_row) ~= "table" then
        callback(false, nil, "character-row-required")
        return true
    end

    faction_id = normalize_positive_integer(character_row.faction_id)
    rank_id = normalize_positive_integer(character_row.rank_id)

    resolution = {
        character_id = normalize_positive_integer(character_row.id),
        faction_id = faction_id,
        rank_id = rank_id,
        faction = nil,
        rank = nil,
    }

    if faction_id == nil and rank_id == nil then
        callback(true, resolution, nil)
        return true
    end

    local function finalize_success()
        callback(true, resolution, nil)
    end

    local function load_missing_faction_from_rank_or_finish()
        if resolution.faction ~= nil then
            finalize_success()
            return
        end

        if resolution.faction_id == nil then
            finalize_success()
            return
        end

        self:GetFactionById(resolution.faction_id, function(is_success, faction_row, error)
            if not is_success then
                callback(false, nil, error)
                return
            end

            resolution.faction = faction_row
            finalize_success()
        end)
    end

    local function load_rank_or_finish()
        if rank_id == nil then
            load_missing_faction_from_rank_or_finish()
            return
        end

        self:GetRankById(rank_id, function(is_success, rank_row, error)
            if not is_success then
                callback(false, nil, error)
                return
            end

            resolution.rank = rank_row

            if resolution.faction_id == nil and type(rank_row) == "table" then
                resolution.faction_id = normalize_positive_integer(rank_row.faction_id)
            end

            load_missing_faction_from_rank_or_finish()
        end)
    end

    if faction_id ~= nil then
        self:GetFactionById(faction_id, function(is_success, faction_row, error)
            if not is_success then
                callback(false, nil, error)
                return
            end

            resolution.faction = faction_row
            load_rank_or_finish()
        end)
    else
        load_rank_or_finish()
    end

    return true
end

GRFactions.Server.FactionRepositoryClass = FactionRepository

return FactionRepository

GRFactions = GRFactions or {}
GRFactions.Server = GRFactions.Server or {}

local FactionService = {}
FactionService.__index = FactionService

local function resolve_characters_bridge()
    if type(GRCharactersBridge) == "table"
        and type(GRCharactersBridge.GetActiveCharacter) == "function"
    then
        return GRCharactersBridge
    end

    return nil
end

local function callback_repository_missing(callback)
    if type(callback) == "function" then
        callback(false, nil, "faction-repository-missing")
    end

    return true
end

function FactionService.Create(repository)
    local self = setmetatable({}, FactionService)

    self.repository = repository

    return self
end

function FactionService:ListFactions(callback)
    if self.repository == nil then
        return callback_repository_missing(callback)
    end

    return self.repository:ListFactions(callback)
end

function FactionService:GetFactionById(faction_id, callback)
    if self.repository == nil then
        return callback_repository_missing(callback)
    end

    return self.repository:GetFactionById(faction_id, callback)
end

function FactionService:ListRanks(callback)
    if self.repository == nil then
        return callback_repository_missing(callback)
    end

    return self.repository:ListRanks(callback)
end

function FactionService:ListRanksByFactionId(faction_id, callback)
    if self.repository == nil then
        return callback_repository_missing(callback)
    end

    return self.repository:ListRanksByFactionId(faction_id, callback)
end

function FactionService:GetRankById(rank_id, callback)
    if self.repository == nil then
        return callback_repository_missing(callback)
    end

    return self.repository:GetRankById(rank_id, callback)
end

function FactionService:AssignCharacterFaction(character_id, faction_id, rank_id, callback)
    if self.repository == nil then
        return callback_repository_missing(callback)
    end

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    return self.repository:AssignCharacterFaction(character_id, faction_id, rank_id, function(is_success, result, error)
        if not is_success then
            callback(false, nil, error)
            return
        end

        Console.Log(
            "[gr_factions][server] Character faction updated character_id=%s faction_id=%s rank_id=%s.",
            tostring(result.character_id),
            tostring(result.faction_id),
            tostring(result.rank_id)
        )

        self:ResolveCharacterFaction({
            id = result.character_id,
            faction_id = result.faction_id,
            rank_id = result.rank_id,
        }, function(resolve_success, resolution, resolve_error)
            if not resolve_success then
                callback(false, nil, resolve_error)
                return
            end

            callback(true, resolution, nil)
        end)
    end)
end

function FactionService:ResolveCharacterFaction(character_row, callback)
    if self.repository == nil then
        return callback_repository_missing(callback)
    end

    return self.repository:ResolveFactionAndRank(character_row, callback)
end

function FactionService:ResolveActiveCharacterFaction(player_or_platform_id, callback)
    local characters_bridge = nil
    local active_character = nil
    local active_character_id = nil

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    characters_bridge = resolve_characters_bridge()

    if characters_bridge == nil then
        callback(false, nil, "characters-bridge-unavailable")
        return true
    end

    active_character = characters_bridge.GetActiveCharacter(player_or_platform_id)

    if type(active_character) ~= "table" then
        callback(true, {
            character_id = nil,
            faction_id = nil,
            rank_id = nil,
            faction = nil,
            rank = nil,
        }, nil)
        return true
    end

    active_character_id = active_character.id

    if active_character_id == nil then
        callback(false, nil, "active-character-id-missing")
        return true
    end

    if self.repository == nil then
        return callback_repository_missing(callback)
    end

    return self.repository:GetCharacterAffiliation(active_character_id, function(is_success, character_affiliation, error)
        if not is_success then
            callback(false, nil, error)
            return
        end

        if character_affiliation == nil then
            callback(false, nil, "character-not-found")
            return
        end

        self:ResolveCharacterFaction(character_affiliation, callback)
    end)
end

function FactionService:DebugLogActiveCharacterFaction(player_or_platform_id, callback)
    return self:ResolveActiveCharacterFaction(player_or_platform_id, function(is_success, resolution, error)
        if is_success then
            local character_id = nil
            local faction_name = nil
            local rank_name = nil

            if type(resolution) == "table" then
                character_id = resolution.character_id

                if type(resolution.faction) == "table" then
                    faction_name = resolution.faction.name
                end

                if type(resolution.rank) == "table" then
                    rank_name = resolution.rank.name
                end
            end

            Console.Log(
                "[gr_factions][server] character_id=%s faction=%s rank=%s.",
                tostring(character_id),
                tostring(faction_name),
                tostring(rank_name)
            )
        else
            Console.Log(
                "[gr_factions][server] Active character faction resolution failed with error=%s.",
                tostring(error)
            )
        end

        if type(callback) == "function" then
            callback(is_success, resolution, error)
        end
    end)
end

GRFactions.Server.FactionServiceClass = FactionService

return FactionService

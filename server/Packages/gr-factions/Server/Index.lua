Package.Require("../Shared/Index.lua")

local FactionRepository = Package.Require("FactionRepository.lua")
local FactionService = Package.Require("FactionService.lua")

GRFactions = GRFactions or {}
GRFactions.Server = GRFactions.Server or {}

local function resolve_database_service()
    if type(GRDatabaseBridge) == "table" and type(GRDatabaseBridge.GetService) == "function" then
        return GRDatabaseBridge.GetService()
    end

    return nil
end

local function callback_service_missing(callback)
    if type(callback) == "function" then
        callback(false, nil, "faction-service-missing")
    end

    return true
end

local database_service = resolve_database_service()

GRFactions.Server.Repository = FactionRepository.Create(database_service)
GRFactions.Server.Service = FactionService.Create(GRFactions.Server.Repository)

if database_service ~= nil then
    Console.Log("[gr_factions][server] Database service resolved through GRDatabaseBridge.")
else
    Console.Log("[gr_factions][server] Database service unavailable because GRDatabaseBridge is missing.")
end

local GRFactionsBridge = {
    GetService = function()
        return GRFactions.Server.Service
    end,
    ListFactions = function(callback)
        if GRFactions.Server.Service == nil then
            return callback_service_missing(callback)
        end

        return GRFactions.Server.Service:ListFactions(callback)
    end,
    GetFactionById = function(faction_id, callback)
        if GRFactions.Server.Service == nil then
            return callback_service_missing(callback)
        end

        return GRFactions.Server.Service:GetFactionById(faction_id, callback)
    end,
    ListRanks = function(callback)
        if GRFactions.Server.Service == nil then
            return callback_service_missing(callback)
        end

        return GRFactions.Server.Service:ListRanks(callback)
    end,
    ListRanksByFactionId = function(faction_id, callback)
        if GRFactions.Server.Service == nil then
            return callback_service_missing(callback)
        end

        return GRFactions.Server.Service:ListRanksByFactionId(faction_id, callback)
    end,
    GetRankById = function(rank_id, callback)
        if GRFactions.Server.Service == nil then
            return callback_service_missing(callback)
        end

        return GRFactions.Server.Service:GetRankById(rank_id, callback)
    end,
    AssignCharacterFaction = function(character_id, faction_id, rank_id, callback)
        if GRFactions.Server.Service == nil then
            return callback_service_missing(callback)
        end

        return GRFactions.Server.Service:AssignCharacterFaction(character_id, faction_id, rank_id, callback)
    end,
    ResolveActiveCharacterFaction = function(player_or_platform_id, callback)
        if GRFactions.Server.Service == nil then
            return callback_service_missing(callback)
        end

        return GRFactions.Server.Service:ResolveActiveCharacterFaction(player_or_platform_id, callback)
    end,
    DebugLogActiveCharacterFaction = function(player_or_platform_id, callback)
        if GRFactions.Server.Service == nil then
            return callback_service_missing(callback)
        end

        return GRFactions.Server.Service:DebugLogActiveCharacterFaction(player_or_platform_id, callback)
    end,
}

Package.Export("GRFactionsBridge", GRFactionsBridge)

if type(Console) == "table" and type(Console.RegisterCommand) == "function" then
    Console.RegisterCommand("setfaction", function(character_id, faction_id, rank_id)
        local function normalize_assignment_value(raw_value)
            if type(raw_value) ~= "string" then
                return raw_value
            end

            local lowered_value = string.lower(raw_value)

            if lowered_value == "" or lowered_value == "nil" or lowered_value == "null" or lowered_value == "none" or lowered_value == "0" then
                return nil
            end

            return raw_value
        end

        if GRFactions.Server.Service == nil then
            Console.Log("[gr_factions][server] setfaction failed because faction service is unavailable.")
            return
        end

        GRFactions.Server.Service:AssignCharacterFaction(
            character_id,
            normalize_assignment_value(faction_id),
            normalize_assignment_value(rank_id),
            function(is_success, resolution, error)
                if not is_success then
                    Console.Log(
                        "[gr_factions][server] setfaction failed character_id=%s error=%s.",
                        tostring(character_id),
                        tostring(error)
                    )
                    return
                end

                Console.Log(
                    "[gr_factions][server] setfaction applied character_id=%s faction_id=%s rank_id=%s.",
                    tostring(resolution and resolution.character_id),
                    tostring(resolution and resolution.faction_id),
                    tostring(resolution and resolution.rank_id)
                )
            end
        )
    end, "assigns or clears a faction and rank on a character", { "character_id", "faction_id|nil", "rank_id|nil" })
end

Console.Log("[gr_factions][server] Factions package loaded.")
Console.Log("[gr_factions][server] Factions bridge exported.")

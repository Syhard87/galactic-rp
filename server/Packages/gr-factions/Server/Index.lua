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

Console.Log("[gr_factions][server] Factions package loaded.")
Console.Log("[gr_factions][server] Factions bridge exported.")

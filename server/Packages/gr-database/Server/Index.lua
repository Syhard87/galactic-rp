Package.Require("../Shared/Index.lua")

local DatabaseConfig = Package.Require("DatabaseConfig.lua")
local DatabaseService = Package.Require("DatabaseService.lua")

GRDatabase = GRDatabase or {}
GRDatabase.Server = GRDatabase.Server or {}

local config = DatabaseConfig.Read()
DatabaseConfig.LogSummary(config)

GRDatabase.Server.Config = config
GRDatabase.Server.Service = DatabaseService.Create(config)

local function GetDatabaseService()
    if GRDatabase == nil then
        return nil
    end

    if GRDatabase.Server == nil then
        return nil
    end

    return GRDatabase.Server.Service
end

local function IsDatabaseServiceReady()
    local service = GetDatabaseService()

    if service == nil then
        return false
    end

    if type(service.IsConnected) == "function" then
        return service:IsConnected()
    end

    return true
end

GRDatabaseBridge = {
    GetService = GetDatabaseService,
    IsReady = IsDatabaseServiceReady
}

Package.Export("GRDatabaseBridge", GRDatabaseBridge)

if config.auto_connect == true then
    Console.Log("[gr_database][server] PostgreSQL auto_connect=true, attempting connection...")
    GRDatabase.Server.Service:ConnectAndRunSmokeTests()
else
    Console.Log("[gr_database][server] PostgreSQL auto_connect=false, skipping automatic connection.")
end

Package.Subscribe("Unload", function()
    local service = GetDatabaseService()

    if service ~= nil and type(service.Disconnect) == "function" then
        service:Disconnect()
    end
end)

Console.Log("[gr_database][server] Database package loaded.")
Console.Log("[gr_database][server] Sensitive database logic remains server-only.")
Console.Log("[gr_database][server] PostgreSQL runtime access stays server-only.")
Console.Log("[gr_database][server] Database bridge exported.")

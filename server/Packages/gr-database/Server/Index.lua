Package.Require("../Shared/Index.lua")

local DatabaseConfig = Package.Require("DatabaseConfig.lua")
local DatabaseService = Package.Require("DatabaseService.lua")

GRDatabase = GRDatabase or {}
GRDatabase.Server = GRDatabase.Server or {}

local config = DatabaseConfig.Read()
DatabaseConfig.LogSummary(config)

GRDatabase.Server.Config = config
GRDatabase.Server.Service = DatabaseService.Create(config)

if config.auto_connect == true then
    Console.Log("[gr_database][server] PostgreSQL auto_connect=true, attempting connection...")
    GRDatabase.Server.Service:ConnectAndRunSmokeTests()
else
    Console.Log("[gr_database][server] PostgreSQL auto_connect=false, skipping automatic connection.")
end

Package.Subscribe("Unload", function()
    GRDatabase.Server.Service:Disconnect()
end)

Console.Log("[gr_database][server] Database package loaded.")
Console.Log("[gr_database][server] Sensitive database logic remains server-only.")
Console.Log("[gr_database][server] PostgreSQL runtime access stays server-only.")

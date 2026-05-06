Package.Require("../Shared/Index.lua")

local DatabaseConfig = Package.Require("DatabaseConfig.lua")
local DatabaseService = Package.Require("DatabaseService.lua")

GRDatabase = GRDatabase or {}
GRDatabase.Server = GRDatabase.Server or {}

local config = DatabaseConfig.Read()
DatabaseConfig.LogSummary(config)

GRDatabase.Server.Config = config
GRDatabase.Server.Service = DatabaseService.Create(config)

Console.Log("[gr_database][server] Database package loaded.")
Console.Log("[gr_database][server] Sensitive database logic remains server-only.")
Console.Log("[gr_database][server] No automatic PostgreSQL connection is attempted at package load.")

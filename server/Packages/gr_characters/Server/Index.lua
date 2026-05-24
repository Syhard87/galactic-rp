Package.Require("../Shared/Index.lua")

local CharacterRepository = Package.Require("CharacterRepository.lua")
local CharacterService = Package.Require("CharacterService.lua")

GRCharacters = GRCharacters or {}
GRCharacters.Server = GRCharacters.Server or {}

local database_service = nil

if GRDatabase ~= nil and GRDatabase.Server ~= nil then
    database_service = GRDatabase.Server.Service
end

GRCharacters.Server.Repository = CharacterRepository.Create(database_service)
GRCharacters.Server.Service = CharacterService.Create(GRCharacters.Server.Repository)

Console.Log("[gr_characters][server] Characters package loaded.")
Console.Log("[gr_characters][server] Character authority, validation and persistence stay server-side.")
Console.Log("[gr_characters][server] Repository and service stubs are ready for future character lifecycle work.")

Package.Require("../Shared/Index.lua")

local CharacterPlayerRepository = Package.Require("CharacterPlayerRepository.lua")
local CharacterPlayerService = Package.Require("CharacterPlayerService.lua")
local CharacterCreationService = Package.Require("CharacterCreationService.lua")
local CharacterSelectionService = Package.Require("CharacterSelectionService.lua")
local CharacterRepository = Package.Require("CharacterRepository.lua")
local CharacterService = Package.Require("CharacterService.lua")

GRCharacters = GRCharacters or {}
GRCharacters.Server = GRCharacters.Server or {}

local database_service = nil

if GRDatabase ~= nil and GRDatabase.Server ~= nil then
    database_service = GRDatabase.Server.Service
end

GRCharacters.Server.PlayerRepository = CharacterPlayerRepository.Create(database_service)
GRCharacters.Server.PlayerService = CharacterPlayerService.Create(GRCharacters.Server.PlayerRepository)
GRCharacters.Server.Repository = CharacterRepository.Create(database_service)
GRCharacters.Server.CreationService = CharacterCreationService.Create(GRCharacters.Server.Repository)
GRCharacters.Server.SelectionService = CharacterSelectionService.Create(
    GRCharacters.Server.Repository,
    GRCharacters.Server.PlayerService
)
GRCharacters.Server.Service = CharacterService.Create(
    GRCharacters.Server.Repository,
    GRCharacters.Server.CreationService,
    GRCharacters.Server.PlayerService,
    GRCharacters.Server.SelectionService
)

local function load_player_session(player)
    local is_started, error = GRCharacters.Server.Service:LoadPlayerSession(player)

    if not is_started then
        Console.Log(
            "[gr_characters][server] Failed to start player row loading for a joining player with error=%s.",
            tostring(error)
        )
    end
end

Player.Subscribe("Spawn", load_player_session)

Player.Subscribe("Destroy", function(player)
    GRCharacters.Server.Service:ForgetPlayerSession(player)
end)

Package.Subscribe("Load", function()
    for _, player in pairs(Player.GetAll()) do
        load_player_session(player)
    end
end)

Console.Log("[gr_characters][server] Characters package loaded.")
Console.Log("[gr_characters][server] Character authority, validation and persistence stay server-side.")
Console.Log("[gr_characters][server] Player row loading is prepared server-side through players.platform_id lookup.")
Console.Log("[gr_characters][server] Character creation is prepared server-side with strict field validation and safe defaults.")
Console.Log("[gr_characters][server] Character selection is prepared server-side with ownership validation and transient active character state.")
Console.Log("[gr_characters][server] Character repositories and services remain separated from character creation, selection, spawn and persistence flows.")

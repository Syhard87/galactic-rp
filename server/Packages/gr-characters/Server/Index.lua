Package.Require("../Shared/Index.lua")

local CharacterPlayerRepository = Package.Require("CharacterPlayerRepository.lua")
local CharacterPlayerService = Package.Require("CharacterPlayerService.lua")
local CharacterCreationService = Package.Require("CharacterCreationService.lua")
local CharacterSelectionService = Package.Require("CharacterSelectionService.lua")
local CharacterPositionService = Package.Require("CharacterPositionService.lua")
local CharacterRepository = Package.Require("CharacterRepository.lua")
local CharacterService = Package.Require("CharacterService.lua")
local CharacterDevTool = Package.Require("CharacterDevTool.lua")

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
GRCharacters.Server.PositionService = CharacterPositionService.Create(
    GRCharacters.Server.Repository,
    GRCharacters.Server.PlayerService,
    GRCharacters.Server.SelectionService
)
GRCharacters.Server.Service = CharacterService.Create(
    GRCharacters.Server.Repository,
    GRCharacters.Server.CreationService,
    GRCharacters.Server.PlayerService,
    GRCharacters.Server.SelectionService,
    GRCharacters.Server.PositionService
)
GRCharacters.Server.DevTool = CharacterDevTool.Create(
    GRCharacters.Server.Service,
    GRCharacters.Server.PlayerService
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
    local platform_id = nil

    if type(player.GetAccountID) == "function" then
        platform_id = player:GetAccountID()
    end

    local is_save_started, save_error = GRCharacters.Server.Service:SaveActiveCharacterPosition(player, function()
        if platform_id ~= nil then
            GRCharacters.Server.Service:ForgetPlayerPositionState(platform_id)
        end
    end, {
        force = true,
        reason = "player-destroy",
    })

    if not is_save_started then
        Console.Log(
            "[gr_characters][server] Failed to start final position save before player session cleanup with error=%s.",
            tostring(save_error)
        )

        if platform_id ~= nil then
            GRCharacters.Server.Service:ForgetPlayerPositionState(platform_id)
        end
    end

    GRCharacters.Server.Service:ForgetPlayerSession(platform_id or player)
end)

Package.Subscribe("Load", function()
    GRCharacters.Server.Service:StartPositionAutoSave()

    for _, player in pairs(Player.GetAll()) do
        load_player_session(player)
    end

    GRCharacters.Server.DevTool:Run()
end)

Package.Subscribe("Unload", function()
    GRCharacters.Server.Service:StopPositionAutoSave()
end)

Console.Log("[gr_characters][server] Characters package loaded.")
Console.Log("[gr_characters][server] Character authority, validation and persistence stay server-side.")
Console.Log("[gr_characters][server] Player row loading is prepared server-side through players.platform_id lookup.")
Console.Log("[gr_characters][server] Character creation is prepared server-side with strict field validation and safe defaults.")
Console.Log("[gr_characters][server] Character selection is prepared server-side with ownership validation and transient active character state.")
Console.Log("[gr_characters][server] Active character position saving is prepared server-side with a slow timer, DB anti-spam and spawn fallback resolution.")
Console.Log("[gr_characters][server] Character repositories and services remain separated from character creation, selection, spawn and persistence flows.")

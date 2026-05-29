Package.Require("../Shared/Index.lua")

local CharacterSessionState = Package.Require("CharacterSessionState.lua")
local CharacterPlayerRepository = Package.Require("CharacterPlayerRepository.lua")
local CharacterPlayerService = Package.Require("CharacterPlayerService.lua")
local CharacterCreationService = Package.Require("CharacterCreationService.lua")
local CharacterSelectionService = Package.Require("CharacterSelectionService.lua")
local CharacterPositionService = Package.Require("CharacterPositionService.lua")
local CharacterRepository = Package.Require("CharacterRepository.lua")
local CharacterService = Package.Require("CharacterService.lua")
local CharacterDevTool = Package.Require("CharacterDevTool.lua")
local CharacterFlowService = Package.Require("CharacterFlowService.lua")
local CharacterRuntimeSelfTest = Package.Require("CharacterRuntimeSelfTest.lua")

GRCharacters = GRCharacters or {}
GRCharacters.Server = GRCharacters.Server or {}

local function resolve_database_service()
    if GRDatabaseBridge == nil then
        Console.Log("[gr_characters][server] Database bridge unavailable. Character repositories start without a DB service.")
        return nil
    end

    if type(GRDatabaseBridge.GetService) ~= "function" then
        Console.Log("[gr_characters][server] Database bridge invalid. GetService is missing.")
        return nil
    end

    local database_service = GRDatabaseBridge.GetService()

    if database_service == nil then
        Console.Log("[gr_characters][server] Database bridge returned nil service.")
        return nil
    end

    Console.Log("[gr_characters][server] Database service resolved through GRDatabaseBridge.")

    return database_service
end

local database_service = resolve_database_service()

GRCharacters.Server.CharacterSessionState = CharacterSessionState.Create()
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
    GRCharacters.Server.PositionService,
    GRCharacters.Server.CharacterSessionState
)
GRCharacters.Server.DevTool = CharacterDevTool.Create(
    GRCharacters.Server.Service,
    GRCharacters.Server.PlayerService
)
GRCharacters.Server.FlowService = CharacterFlowService.Create(
    GRCharacters.Server.Service,
    GRCharacters.Server.PlayerService,
    GRCharacters.Server.DevTool,
    GRCharacters.Server.CharacterSessionState
)
GRCharacters.Server.RuntimeSelfTest = CharacterRuntimeSelfTest.Create(
    database_service,
    GRCharacters.Server.Service,
    GRCharacters.Server.PlayerService
)

local function start_player_character_flow(player, source_label)
    local is_started, error = GRCharacters.Server.FlowService:ProcessConnectedPlayer(player, source_label)

    if not is_started then
        Console.Log(
            "[gr_characters][server] Failed to start the player active character flow with error=%s.",
            tostring(error)
        )
    end
end

local function guard_player_gameplay_readiness(player, source_label)
    if GRCharacters.Server.Service == nil or type(GRCharacters.Server.Service.IsGameplayReady) ~= "function" then
        Console.Log(
            "[gr_characters][server] gameplay-ready=false source=%s reason=%s status=%s.",
            tostring(source_label or "unknown"),
            "character-service-unavailable",
            "unknown"
        )
        return false, "character-service-unavailable"
    end

    local platform_id = nil

    if type(player) == "table" or type(player) == "userdata" then
        if type(player.GetAccountID) == "function" then
            platform_id = player:GetAccountID()
        end
    end

    local is_ready, reason = GRCharacters.Server.Service:IsGameplayReady(platform_id or player)
    local status = GRCharacters.Server.Service:GetCharacterSessionStatus(platform_id or player) or "missing"

    Console.Log(
        "[gr_characters][server] gameplay-ready=%s platform_id=%s source=%s reason=%s status=%s.",
        tostring(is_ready),
        tostring(platform_id),
        tostring(source_label or "unknown"),
        tostring(reason),
        tostring(status)
    )

    return is_ready, reason
end

Player.Subscribe("Ready", function(player)
    start_player_character_flow(player, "player-ready")
end)

Player.Subscribe("Spawn", function(player)
    guard_player_gameplay_readiness(player, "player-spawn")
end)

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
    GRCharacters.Server.RuntimeSelfTest:Run()

    for _, player in pairs(Player.GetAll()) do
        start_player_character_flow(player, "package-load-reconcile")
    end

    GRCharacters.Server.DevTool:LogStatus()
end)

Package.Subscribe("Unload", function()
    GRCharacters.Server.Service:StopPositionAutoSave()
end)

Console.Log("[gr_characters][server] Characters package loaded.")
Console.Log("[gr_characters][server] Character authority, validation and persistence stay server-side.")
Console.Log("[gr_characters][server] Player-ready flow is server-only and uses players.platform_id lookup plus in-memory active character selection.")
Console.Log("[gr_characters][server] Character creation is prepared server-side with strict field validation and safe defaults.")
Console.Log("[gr_characters][server] Character selection is prepared server-side with ownership validation and transient active character state.")
Console.Log("[gr_characters][server] Active character position saving is prepared server-side with a slow timer, DB anti-spam and spawn fallback resolution.")
Console.Log("[gr_characters][server] Character session readiness gate is tracked server-side by platform_id.")
Console.Log("[gr_characters][server] Character repositories and services remain separated from character creation, selection, spawn and persistence flows.")

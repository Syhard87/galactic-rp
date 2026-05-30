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

local function resolve_player_platform_id(player)
    if type(player) ~= "table" and type(player) ~= "userdata" then
        return nil
    end

    if type(player.GetAccountID) ~= "function" then
        return nil
    end

    return player:GetAccountID()
end

local function find_player_by_platform_id(platform_id)
    if platform_id == nil then
        return nil
    end

    for _, connected_player in pairs(Player.GetAll()) do
        if resolve_player_platform_id(connected_player) == platform_id then
            return connected_player
        end
    end

    return nil
end

local function get_creation_policy_for_client()
    if GRCharacters.Server == nil or GRCharacters.Server.CreationService == nil then
        return nil
    end

    if type(GRCharacters.Server.CreationService.GetPolicy) ~= "function" then
        return nil
    end

    local policy = GRCharacters.Server.CreationService:GetPolicy()

    if type(policy) ~= "table" then
        return nil
    end

    return {
        min_age = policy.min_age,
        max_age = policy.max_age,
        min_name_length = policy.min_name_length,
        max_name_length = policy.max_name_length,
        max_species_length = policy.max_species_length,
        max_biography_length = policy.max_biography_length,
        default_species = policy.default_species,
    }
end

local function notify_character_creation_required(platform_id)
    local player = find_player_by_platform_id(platform_id)

    if player == nil then
        Console.Log(
            "[gr_characters][server] Character creation UI request skipped because player is not connected for platform_id=%s.",
            tostring(platform_id)
        )
        return false
    end

    Events.CallRemote(GRCharacters.Shared.Events.OPEN_CHARACTER_CREATION, player, {
        status = "pending-character-creation",
        policy = get_creation_policy_for_client(),
    })

    Console.Log(
        "[gr_characters][server] Character creation UI requested for platform_id=%s.",
        tostring(platform_id)
    )

    return true
end

local function build_character_selection_list_for_client(selection_state)
    local characters = {}

    if type(selection_state) ~= "table" or type(selection_state.characters) ~= "table" then
        return characters
    end

    for _, character_row in ipairs(selection_state.characters) do
        if type(character_row) == "table" and character_row.id ~= nil then
            characters[#characters + 1] = {
                id = character_row.id,
                first_name = character_row.first_name,
                last_name = character_row.last_name,
                age = character_row.age,
                species = character_row.species,
            }
        end
    end

    return characters
end

local function notify_character_selection_required(platform_id, selection_state)
    local player = find_player_by_platform_id(platform_id)

    if player == nil then
        Console.Log(
            "[gr_characters][server] Character selection UI request skipped because player is not connected for platform_id=%s.",
            tostring(platform_id)
        )
        return false
    end

    local characters = build_character_selection_list_for_client(selection_state)

    Events.CallRemote(GRCharacters.Shared.Events.OPEN_CHARACTER_SELECTION, player, {
        status = "waiting-character-selection",
        characters = characters,
    })

    Console.Log(
        "[gr_characters][server] Character selection UI requested for platform_id=%s character_count=%s.",
        tostring(platform_id),
        tostring(#characters)
    )

    return true
end

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
    GRCharacters.Server.CharacterSessionState,
    notify_character_creation_required,
    notify_character_selection_required
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

local function send_character_creation_result(player, result)
    if player == nil then
        return false
    end

    Events.CallRemote(GRCharacters.Shared.Events.CHARACTER_CREATION_RESULT, player, result)
    return true
end

local function send_character_selection_result(player, result)
    if player == nil then
        return false
    end

    Events.CallRemote(GRCharacters.Shared.Events.CHARACTER_SELECTION_RESULT, player, result)
    return true
end

local function resolve_requested_character_id(payload)
    if type(payload) == "number" or type(payload) == "string" then
        return payload
    end

    if type(payload) ~= "table" then
        return nil
    end

    return payload.character_id or payload.id
end

Events.SubscribeRemote(GRCharacters.Shared.Events.SUBMIT_CHARACTER_SELECTION, function(player, payload)
    local platform_id = resolve_player_platform_id(player)

    if platform_id == nil then
        Console.Log("[gr_characters][server] Character selection request rejected because platform_id is unavailable.")
        send_character_selection_result(player, {
            success = false,
            code = "platform-id-required",
        })
        return
    end

    if GRCharacters.Server.Service == nil or type(GRCharacters.Server.Service.SelectActiveCharacter) ~= "function" then
        Console.Log(
            "[gr_characters][server] Character selection request rejected for platform_id=%s because service is unavailable.",
            tostring(platform_id)
        )
        send_character_selection_result(player, {
            success = false,
            code = "character-service-unavailable",
        })
        return
    end

    local character_id = resolve_requested_character_id(payload)

    Console.Log(
        "[gr_characters][server] Character selection request received for platform_id=%s character_id=%s.",
        tostring(platform_id),
        tostring(character_id)
    )

    local is_started, error = GRCharacters.Server.Service:SelectActiveCharacter(platform_id, character_id, function(is_success, result)
        if not is_success then
            local error_code = result and result.code or "character-selection-failed"

            Console.Log(
                "[gr_characters][server] Character selection request failed for platform_id=%s character_id=%s code=%s.",
                tostring(platform_id),
                tostring(character_id),
                tostring(error_code)
            )

            send_character_selection_result(player, {
                success = false,
                code = error_code,
            })
            return
        end

        local is_ready, readiness_reason = GRCharacters.Server.Service:IsGameplayReady(platform_id)
        local selected_character = result and result.character or nil

        Console.Log(
            "[gr_characters][server] Character selection request completed for platform_id=%s character_id=%s gameplay-ready=%s.",
            tostring(platform_id),
            tostring(result and result.active_character_id or character_id),
            tostring(is_ready)
        )

        send_character_selection_result(player, {
            success = true,
            code = "character-selected",
            active_character_id = result and result.active_character_id or character_id,
            first_name = selected_character and selected_character.first_name or nil,
            last_name = selected_character and selected_character.last_name or nil,
            gameplay_ready = is_ready,
            readiness_reason = readiness_reason,
        })
    end)

    if not is_started then
        Console.Log(
            "[gr_characters][server] Character selection request dispatch failed for platform_id=%s with error=%s.",
            tostring(platform_id),
            tostring(error)
        )

        send_character_selection_result(player, {
            success = false,
            code = error or "character-selection-dispatch-failed",
        })
    end
end)

Events.SubscribeRemote(GRCharacters.Shared.Events.SUBMIT_CHARACTER_CREATION, function(player, character_payload)
    local platform_id = resolve_player_platform_id(player)

    if platform_id == nil then
        Console.Log("[gr_characters][server] Character creation request rejected because platform_id is unavailable.")
        send_character_creation_result(player, {
            success = false,
            code = "platform-id-required",
        })
        return
    end

    if GRCharacters.Server.Service == nil or type(GRCharacters.Server.Service.CreateCharacterAndSelect) ~= "function" then
        Console.Log(
            "[gr_characters][server] Character creation request rejected for platform_id=%s because service is unavailable.",
            tostring(platform_id)
        )
        send_character_creation_result(player, {
            success = false,
            code = "character-service-unavailable",
        })
        return
    end

    Console.Log(
        "[gr_characters][server] Character creation request received for platform_id=%s.",
        tostring(platform_id)
    )

    local is_started, error = GRCharacters.Server.Service:CreateCharacterAndSelect(platform_id, character_payload, function(is_success, result)
        if not is_success then
            local error_code = result and result.code or "character-create-failed"

            Console.Log(
                "[gr_characters][server] Character creation request failed for platform_id=%s with code=%s.",
                tostring(platform_id),
                tostring(error_code)
            )

            send_character_creation_result(player, {
                success = false,
                code = error_code,
                details = result and result.details or nil,
                status = result and result.status or nil,
            })
            return
        end

        local created_character = result and result.character or nil

        Console.Log(
            "[gr_characters][server] Character creation request completed for platform_id=%s character_id=%s gameplay-ready=%s.",
            tostring(platform_id),
            tostring(result and result.active_character_id or nil),
            tostring(result and result.gameplay_ready or false)
        )

        send_character_creation_result(player, {
            success = true,
            code = "character-created-and-selected",
            active_character_id = result and result.active_character_id or nil,
            first_name = created_character and created_character.first_name or nil,
            last_name = created_character and created_character.last_name or nil,
            gameplay_ready = result and result.gameplay_ready or false,
        })
    end)

    if not is_started then
        Console.Log(
            "[gr_characters][server] Character creation request dispatch failed for platform_id=%s with error=%s.",
            tostring(platform_id),
            tostring(error)
        )

        send_character_creation_result(player, {
            success = false,
            code = error or "character-create-dispatch-failed",
        })
    end
end)

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

Package.Require("../Shared/Index.lua")

local character_events = GRCharacters.Shared.Events
local character_creation_ui = nil
local is_character_creation_ui_ready = false
local pending_ui_calls = {}
local close_character_creation_ui = nil
local character_selection_ui = nil
local is_character_selection_ui_ready = false
local pending_selection_ui_calls = {}
local close_character_selection_ui = nil

local function set_form_input_enabled(is_enabled)
    if Input == nil then
        return
    end

    if type(Input.SetInputEnabled) == "function" then
        Input.SetInputEnabled(not is_enabled)
    end

    if type(Input.SetMouseEnabled) == "function" then
        Input.SetMouseEnabled(is_enabled)
    end
end

local function send_payload_to_ui(event_name, payload)
    if character_creation_ui == nil or not is_character_creation_ui_ready then
        pending_ui_calls[#pending_ui_calls + 1] = {
            event_name = event_name,
            payload = payload,
        }
        return
    end

    character_creation_ui:CallEvent(event_name, payload)
end

local function send_payload_to_selection_ui(event_name, payload)
    if character_selection_ui == nil or not is_character_selection_ui_ready then
        pending_selection_ui_calls[#pending_selection_ui_calls + 1] = {
            event_name = event_name,
            payload = payload,
        }
        return
    end

    character_selection_ui:CallEvent(event_name, payload)
end

local function ensure_character_creation_ui()
    if character_creation_ui ~= nil then
        return character_creation_ui
    end

    character_creation_ui = WebUI(
        "Galactic RP Character Creation",
        "file://UI/character-creation.html",
        WidgetVisibility.Visible
    )
    is_character_creation_ui_ready = false

    character_creation_ui:Subscribe("Ready", function()
        is_character_creation_ui_ready = true

        for _, pending_call in ipairs(pending_ui_calls) do
            character_creation_ui:CallEvent(pending_call.event_name, pending_call.payload)
        end

        pending_ui_calls = {}
    end)

    character_creation_ui:Subscribe("SubmitCharacterCreation", function(payload)
        Events.CallRemote(character_events.SUBMIT_CHARACTER_CREATION, payload)
    end)

    character_creation_ui:Subscribe("CloseCharacterCreation", function()
        close_character_creation_ui()
    end)

    return character_creation_ui
end

local function ensure_character_selection_ui()
    if character_selection_ui ~= nil then
        return character_selection_ui
    end

    character_selection_ui = WebUI(
        "Galactic RP Character Selection",
        "file://UI/character-selection.html",
        WidgetVisibility.Visible
    )
    is_character_selection_ui_ready = false

    character_selection_ui:Subscribe("Ready", function()
        is_character_selection_ui_ready = true

        for _, pending_call in ipairs(pending_selection_ui_calls) do
            character_selection_ui:CallEvent(pending_call.event_name, pending_call.payload)
        end

        pending_selection_ui_calls = {}
    end)

    character_selection_ui:Subscribe("SubmitCharacterSelection", function(character_id)
        Events.CallRemote(character_events.SUBMIT_CHARACTER_SELECTION, {
            character_id = character_id,
        })
    end)

    character_selection_ui:Subscribe("CloseCharacterSelection", function()
        close_character_selection_ui()
    end)

    return character_selection_ui
end

local function open_character_creation_ui(payload)
    if character_selection_ui ~= nil and type(close_character_selection_ui) == "function" then
        close_character_selection_ui()
    end

    ensure_character_creation_ui()
    set_form_input_enabled(true)
    send_payload_to_ui("OpenCharacterCreation", payload or {})
    Console.Log("[gr_characters][client] Character creation UI opened.")
end

local function open_character_selection_ui(payload)
    if character_creation_ui ~= nil and type(close_character_creation_ui) == "function" then
        close_character_creation_ui()
    end

    ensure_character_selection_ui()
    set_form_input_enabled(true)
    send_payload_to_selection_ui("OpenCharacterSelection", payload or {})
    Console.Log("[gr_characters][client] Character selection UI opened.")
end

function close_character_creation_ui()
    pending_ui_calls = {}
    is_character_creation_ui_ready = false
    set_form_input_enabled(false)

    if character_creation_ui ~= nil and type(character_creation_ui.Destroy) == "function" then
        character_creation_ui:Destroy()
    end

    character_creation_ui = nil
end

function close_character_selection_ui()
    pending_selection_ui_calls = {}
    is_character_selection_ui_ready = false
    set_form_input_enabled(false)

    if character_selection_ui ~= nil and type(character_selection_ui.Destroy) == "function" then
        character_selection_ui:Destroy()
    end

    character_selection_ui = nil
end

Events.SubscribeRemote(character_events.OPEN_CHARACTER_CREATION, function(payload)
    open_character_creation_ui(payload)
end)

Events.SubscribeRemote(character_events.OPEN_CHARACTER_SELECTION, function(payload)
    open_character_selection_ui(payload)
end)

Events.SubscribeRemote(character_events.CHARACTER_CREATION_RESULT, function(result)
    if character_creation_ui == nil then
        Console.Log("[gr_characters][client] Character creation result received without an open UI.")
        return
    end

    send_payload_to_ui("CharacterCreationResult", result or {})
end)

Events.SubscribeRemote(character_events.CHARACTER_SELECTION_RESULT, function(result)
    if character_selection_ui == nil then
        Console.Log("[gr_characters][client] Character selection result received without an open UI.")
        return
    end

    send_payload_to_selection_ui("CharacterSelectionResult", result or {})
end)

Console.Log("[gr_characters][client] Characters package loaded.")
Console.Log("[gr_characters][client] Character creation and selection UIs are client-side only; validation and persistence stay server-side.")

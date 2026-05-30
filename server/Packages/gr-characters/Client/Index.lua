Package.Require("../Shared/Index.lua")

local creation_events = GRCharacters.Shared.Events
local character_creation_ui = nil
local is_character_creation_ui_ready = false
local pending_ui_calls = {}
local close_character_creation_ui = nil

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
        Events.CallRemote(creation_events.SUBMIT_CHARACTER_CREATION, payload)
    end)

    character_creation_ui:Subscribe("CloseCharacterCreation", function()
        close_character_creation_ui()
    end)

    return character_creation_ui
end

local function open_character_creation_ui(payload)
    ensure_character_creation_ui()
    set_form_input_enabled(true)
    send_payload_to_ui("OpenCharacterCreation", payload or {})
    Console.Log("[gr_characters][client] Character creation UI opened.")
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

Events.SubscribeRemote(creation_events.OPEN_CHARACTER_CREATION, function(payload)
    open_character_creation_ui(payload)
end)

Events.SubscribeRemote(creation_events.CHARACTER_CREATION_RESULT, function(result)
    if character_creation_ui == nil then
        Console.Log("[gr_characters][client] Character creation result received without an open UI.")
        return
    end

    send_payload_to_ui("CharacterCreationResult", result or {})
end)

Console.Log("[gr_characters][client] Characters package loaded.")
Console.Log("[gr_characters][client] Character creation UI is client-side only; validation and persistence stay server-side.")

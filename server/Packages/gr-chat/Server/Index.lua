Package.Require("../Shared/Index.lua")

GRChat = GRChat or {}
GRChat.Server = GRChat.Server or {}

local LOCAL_CHAT_RADIUS_METERS = 25
local LOCAL_CHAT_RADIUS_UNITS = LOCAL_CHAT_RADIUS_METERS * 100
local MAX_LOCAL_CHAT_MESSAGE_LENGTH = 180
local LOCAL_CHAT_PREFIX = "[Local]"
local LOCAL_COMMAND_DO_PREFIX = "[DO]"
local EXTERNAL_CHAT_COMMANDS = {
    abandonquest = true,
    classes = true,
    dropitem = true,
    craft = true,
    craftinfo = true,
    craftrecipes = true,
    craftstations = true,
    contracts = true,
    mycontracts = true,
    createcontract = true,
    acceptcontract = true,
    completecontract = true,
    cancelcontract = true,
    explorereport = true,
    f = true,
    giveitem = true,
    givereputation = true,
    givemoney = true,
    givexp = true,
    giveskillxp = true,
    inv = true,
    money = true,
    pay = true,
    completequest = true,
    profile = true,
    questprogress = true,
    quests = true,
    reputations = true,
    setclass = true,
    skills = true,
    startquest = true,
    takemoney = true,
    transactions = true,
    useitem = true,
    whoami = true,
    xpinfo = true,
}

local function trim_string(value)
    if type(value) ~= "string" then
        return nil
    end

    local trimmed = value:match("^%s*(.-)%s*$")

    if trimmed == nil or trimmed == "" then
        return nil
    end

    return trimmed
end

local function sanitize_chat_message(message)
    if type(message) ~= "string" then
        return nil
    end

    return message:gsub("[<>]", "")
end

local function get_platform_id(player)
    if type(player) ~= "table" and type(player) ~= "userdata" then
        return nil
    end

    if type(player.GetAccountID) ~= "function" then
        return nil
    end

    return player:GetAccountID()
end

local function normalize_chat_submit_arguments(first_argument, second_argument)
    if get_platform_id(first_argument) ~= nil then
        return first_argument, second_argument
    end

    if get_platform_id(second_argument) ~= nil then
        return second_argument, first_argument
    end

    return nil, nil
end

local function get_active_character_row(player)
    local platform_id = get_platform_id(player)

    if platform_id == nil or GRCharactersBridge == nil then
        return nil
    end

    if type(GRCharactersBridge.GetActiveCharacter) ~= "function" then
        return nil
    end

    return GRCharactersBridge.GetActiveCharacter(platform_id)
end

local function is_gameplay_ready(player)
    local platform_id = get_platform_id(player)

    if platform_id == nil then
        return false, "platform-id-required"
    end

    if GRCharactersBridge == nil or type(GRCharactersBridge.IsGameplayReady) ~= "function" then
        return false, "character-bridge-unavailable"
    end

    return GRCharactersBridge.IsGameplayReady(platform_id)
end

local function get_controlled_character(player)
    if type(player) ~= "table" and type(player) ~= "userdata" then
        return nil
    end

    if type(player.GetControlledCharacter) ~= "function" then
        return nil
    end

    return player:GetControlledCharacter()
end

local function get_entity_location(entity)
    if entity == nil or type(entity.GetLocation) ~= "function" then
        return nil
    end

    local location = entity:GetLocation()

    if location == nil then
        return nil
    end

    if type(location.X) ~= "number" or type(location.Y) ~= "number" or type(location.Z) ~= "number" then
        return nil
    end

    return location
end

local function get_player_chat_location(player)
    local controlled_character = get_controlled_character(player)
    return get_entity_location(controlled_character)
end

local function get_distance_squared(first_location, second_location)
    if first_location == nil or second_location == nil then
        return nil
    end

    local delta_x = first_location.X - second_location.X
    local delta_y = first_location.Y - second_location.Y
    local delta_z = first_location.Z - second_location.Z

    return (delta_x * delta_x) + (delta_y * delta_y) + (delta_z * delta_z)
end

local function build_local_chat_message(character_row, message)
    local first_name = trim_string(character_row and character_row.first_name) or "Unknown"
    local last_name = trim_string(character_row and character_row.last_name) or "Character"

    return string.format("%s %s %s: %s", LOCAL_CHAT_PREFIX, first_name, last_name, message)
end

local function build_local_me_message(character_row, message)
    local first_name = trim_string(character_row and character_row.first_name) or "Unknown"
    local last_name = trim_string(character_row and character_row.last_name) or "Character"

    return string.format("* %s %s %s", first_name, last_name, message)
end

local function build_local_do_message(message)
    return string.format("%s %s", LOCAL_COMMAND_DO_PREFIX, message)
end

local function send_rejection_feedback(player, reason)
    if player == nil or type(Chat) ~= "table" or type(Chat.SendMessage) ~= "function" then
        return
    end

    Chat.SendMessage(player, string.format("%s Message rejected: %s.", LOCAL_CHAT_PREFIX, tostring(reason)))
end

local function reject_local_message(player, reason)
    Console.Log("[gr_chat][server] Local RP message rejected reason=%s.", tostring(reason))
    send_rejection_feedback(player, reason)
    return false
end

local function collect_local_recipients(sender_player, sender_location)
    local recipients = {}

    if type(Player) ~= "table" or type(Player.GetAll) ~= "function" then
        return recipients
    end

    local max_distance_squared = LOCAL_CHAT_RADIUS_UNITS * LOCAL_CHAT_RADIUS_UNITS

    for _, candidate_player in pairs(Player.GetAll()) do
        local candidate_location = get_player_chat_location(candidate_player)
        local distance_squared = get_distance_squared(sender_location, candidate_location)

        if distance_squared ~= nil and distance_squared <= max_distance_squared then
            recipients[#recipients + 1] = candidate_player
        end
    end

    return recipients
end

local function distribute_local_message(recipients, formatted_message)
    for _, recipient in ipairs(recipients) do
        Chat.SendMessage(recipient, formatted_message)
    end
end

local function parse_local_chat_mode(message)
    if type(message) ~= "string" or message == "" then
        return nil, nil, "message-required"
    end

    if message:sub(1, 1) ~= "/" then
        return "local", message
    end

    local command_name, command_payload = message:match("^/(%S+)%s*(.*)$")

    if command_name == nil then
        return nil, nil, "chat-command-not-supported"
    end

    command_name = string.lower(command_name)
    command_payload = trim_string(command_payload)

    if command_name == "me" then
        if command_payload == nil then
            return nil, nil, "me-text-required"
        end

        return "me", command_payload
    end

    if command_name == "do" then
        if command_payload == nil then
            return nil, nil, "do-text-required"
        end

        return "do", command_payload
    end

    if EXTERNAL_CHAT_COMMANDS[command_name] == true then
        return nil, nil, "handled-externally"
    end

    return nil, nil, "chat-command-not-supported"
end

local function resolve_local_chat_context(sender_player, raw_message)
    local message = trim_string(raw_message)

    if message == nil then
        return false, "message-required"
    end

    message = trim_string(sanitize_chat_message(message))

    if message == nil then
        return false, "message-required"
    end

    local mode, payload, parse_error = parse_local_chat_mode(message)

    if mode == nil then
        return false, parse_error
    end

    if #payload > MAX_LOCAL_CHAT_MESSAGE_LENGTH then
        return false, "message-too-long"
    end

    local is_ready, readiness_reason = is_gameplay_ready(sender_player)

    if not is_ready then
        return false, readiness_reason or "gameplay-not-ready"
    end

    local active_character = get_active_character_row(sender_player)

    if type(active_character) ~= "table" or active_character.id == nil then
        return false, "active-character-required"
    end

    local sender_location = get_player_chat_location(sender_player)

    if sender_location == nil then
        return false, "sender-location-unavailable"
    end

    if type(Chat) ~= "table" or type(Chat.SendMessage) ~= "function" then
        return false, "chat-send-unavailable"
    end

    local recipients = collect_local_recipients(sender_player, sender_location)

    if #recipients < 1 then
        recipients[1] = sender_player
    end

    return true, {
        mode = mode,
        payload = payload,
        platform_id = get_platform_id(sender_player),
        active_character = active_character,
        recipients = recipients,
    }
end

local function build_formatted_local_message(mode, active_character, payload)
    if mode == "me" then
        return build_local_me_message(active_character, payload)
    end

    if mode == "do" then
        return build_local_do_message(payload)
    end

    return build_local_chat_message(active_character, payload)
end

local function log_accepted_local_message(context)
    if context.mode == "local" then
        Console.Log(
            "[gr_chat][server] Local RP message accepted platform_id=%s character_id=%s.",
            tostring(context.platform_id),
            tostring(context.active_character.id)
        )
        return
    end

    Console.Log(
        "[gr_chat][server] Local RP command accepted command=%s platform_id=%s character_id=%s.",
        tostring(context.mode),
        tostring(context.platform_id),
        tostring(context.active_character.id)
    )
end

local function handle_local_rp_chat(sender_player, raw_message)
    local is_resolved, context_or_reason = resolve_local_chat_context(sender_player, raw_message)

    if not is_resolved then
        if context_or_reason == "handled-externally" then
            return false
        end

        return reject_local_message(sender_player, context_or_reason)
    end

    local formatted_message = build_formatted_local_message(
        context_or_reason.mode,
        context_or_reason.active_character,
        context_or_reason.payload
    )

    distribute_local_message(context_or_reason.recipients, formatted_message)
    log_accepted_local_message(context_or_reason)

    return false
end

if type(Chat) == "table" and type(Chat.Subscribe) == "function" then
    Chat.Subscribe("PlayerSubmit", function(first_argument, second_argument)
        local player, message = normalize_chat_submit_arguments(first_argument, second_argument)

        if player == nil then
            Console.Log("[gr_chat][server] Local RP message rejected reason=%s.", "player-unavailable")
            return false
        end

        return handle_local_rp_chat(player, message)
    end)
else
    Console.Log("[gr_chat][server] Chat.Subscribe is unavailable. Local RP chat interception is disabled.")
end

Console.Log("[gr_chat][server] Chat package loaded.")
Console.Log(
    "[gr_chat][server] Local RP chat is server-authoritative with active character checks and a %sm radius.",
    tostring(LOCAL_CHAT_RADIUS_METERS)
)

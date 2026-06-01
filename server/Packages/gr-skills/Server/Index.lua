Package.Require("../Shared/Index.lua")
Package.Require("../Shared/SkillsConfig.lua")

local SkillXpRules = Package.Require("SkillXpRules.lua")
local SkillRepository = Package.Require("SkillRepository.lua")
local SkillService = Package.Require("SkillService.lua")

GRSkills = GRSkills or {}
GRSkills.Server = GRSkills.Server or {}
local SkillsConfig = GRSkills.Shared and GRSkills.Shared.SkillsConfig

local function resolve_database_service()
    if type(GRDatabaseBridge) == "table" and type(GRDatabaseBridge.GetService) == "function" then
        return GRDatabaseBridge.GetService()
    end

    return nil
end

local function callback_service_missing(callback)
    if type(callback) == "function" then
        callback(false, nil, "skills-service-missing")
    end

    return true
end

local function trim_string(value)
    if type(value) ~= "string" then
        return nil
    end

    local trimmed_value = value:match("^%s*(.-)%s*$")

    if trimmed_value == "" then
        return nil
    end

    return trimmed_value
end

local function normalize_boolean(value, fallback)
    if type(value) == "boolean" then
        return value
    end

    local string_value = trim_string(value)

    if string_value ~= nil then
        local lowered_value = string.lower(string_value)

        if lowered_value == "true" then
            return true
        end

        if lowered_value == "false" then
            return false
        end
    end

    return fallback
end

local function read_custom_settings()
    if type(Server) ~= "table" and type(Server) ~= "userdata" then
        return nil
    end

    if type(Server.GetCustomSettings) ~= "function" then
        return nil
    end

    local is_read, custom_settings = pcall(Server.GetCustomSettings)

    if not is_read or type(custom_settings) ~= "table" then
        return nil
    end

    return custom_settings
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

local function resolve_platform_id(player_or_platform_id)
    local platform_id = get_platform_id(player_or_platform_id)

    if platform_id ~= nil then
        return platform_id
    end

    return trim_string(player_or_platform_id)
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

local function normalize_positive_integer(value)
    if type(value) == "number" then
        if value < 1 or value % 1 ~= 0 then
            return nil
        end

        return math.floor(value)
    end

    if type(value) == "string" and value:match("^%d+$") ~= nil then
        local parsed_value = tonumber(value)

        if parsed_value ~= nil and parsed_value >= 1 then
            return math.floor(parsed_value)
        end
    end

    return nil
end

local function get_chat_command(message)
    local trimmed_message = trim_string(message)

    if trimmed_message == nil or trimmed_message:sub(1, 1) ~= "/" then
        return nil, nil
    end

    local command_name, payload = trimmed_message:match("^/(%S+)%s*(.*)$")

    if command_name == nil then
        return nil, nil
    end

    return string.lower(command_name), trim_string(payload)
end

local function parse_platform_id_allowlist(value)
    local allowlist = {}
    local has_entries = false

    local function add_entry(entry_value)
        local normalized_entry = trim_string(entry_value)

        if normalized_entry == nil then
            return
        end

        allowlist[normalized_entry] = true
        has_entries = true
    end

    if type(value) == "string" then
        for raw_entry in string.gmatch(value, "([^,]+)") do
            add_entry(raw_entry)
        end
    elseif type(value) == "table" then
        for _, entry_value in ipairs(value) do
            add_entry(entry_value)
        end
    end

    return allowlist, has_entries
end

local function can_use_giveskillxp_command(player_or_platform_id)
    local platform_id = resolve_platform_id(player_or_platform_id)
    local custom_settings = nil
    local debug_commands_enabled = false
    local allowlist = nil
    local has_allowlist_entries = false

    if platform_id == nil then
        return false, nil, "platform-id-missing"
    end

    custom_settings = read_custom_settings()

    if type(custom_settings) ~= "table" then
        return false, platform_id, "custom-settings-missing"
    end

    debug_commands_enabled = normalize_boolean(custom_settings.gr_skills_debug_commands_enabled, false)

    if not debug_commands_enabled then
        return false, platform_id, "debug-disabled"
    end

    allowlist, has_allowlist_entries = parse_platform_id_allowlist(custom_settings.gr_skills_debug_allowed_platform_ids)

    if not has_allowlist_entries then
        return false, platform_id, "allowlist-missing"
    end

    if allowlist[platform_id] ~= true then
        return false, platform_id, "not-authorized"
    end

    return true, platform_id, nil
end

local database_service = resolve_database_service()

GRSkills.Server.Repository = SkillRepository.Create(database_service)
GRSkills.Server.Service = SkillService.Create(GRSkills.Server.Repository)

if database_service ~= nil then
    Console.Log("[gr_skills][server] Database service resolved through GRDatabaseBridge.")
else
    Console.Log("[gr_skills][server] Database service unavailable because GRDatabaseBridge is missing.")
end

local GRSkillsBridge = {
    GetService = function()
        return GRSkills.Server.Service
    end,
    ListSkills = function(character_id, callback)
        if GRSkills.Server.Service == nil then
            return callback_service_missing(callback)
        end

        return GRSkills.Server.Service:ListSkills(character_id, callback)
    end,
    ListActiveCharacterSkills = function(player_or_platform_id, callback)
        if GRSkills.Server.Service == nil then
            return callback_service_missing(callback)
        end

        return GRSkills.Server.Service:ListActiveCharacterSkills(player_or_platform_id, callback)
    end,
    AddSkillXp = function(character_id, skill_key, amount, reason, callback)
        if GRSkills.Server.Service == nil then
            return callback_service_missing(callback)
        end

        return GRSkills.Server.Service:AddSkillXp(character_id, skill_key, amount, reason, callback)
    end,
    AddSkillXpToActiveCharacter = function(player_or_platform_id, skill_key, amount, reason, callback)
        if GRSkills.Server.Service == nil then
            return callback_service_missing(callback)
        end

        return GRSkills.Server.Service:AddSkillXpToActiveCharacter(player_or_platform_id, skill_key, amount, reason, callback)
    end,
}

Package.Export("GRSkillsBridge", GRSkillsBridge)

if type(Chat) == "table" and type(Chat.Subscribe) == "function" and type(Chat.SendMessage) == "function" then
    Chat.Subscribe("PlayerSubmit", function(first_argument, second_argument)
        local player, message = normalize_chat_submit_arguments(first_argument, second_argument)
        local command_name = nil
        local payload = nil

        if player == nil then
            return
        end

        command_name, payload = get_chat_command(message)

        if command_name == "skills" then
            GRSkills.Server.Service:ListActiveCharacterSkills(player, function(is_success, skill_rows, error)
                if not is_success then
                    if error == "active-character-missing" then
                        Chat.SendMessage(player, "Aucun personnage actif.")
                        return
                    end

                    Chat.SendMessage(player, "Competences indisponibles.")
                    return
                end

                if type(skill_rows) ~= "table" or #skill_rows == 0 then
                    Chat.SendMessage(player, "Aucune competence.")
                    return
                end

                Chat.SendMessage(player, "Competences :")

                for _, skill_row in ipairs(skill_rows) do
                    local required_xp = SkillXpRules.GetRequiredXpForLevel(skill_row.level)
                    local skill_label = nil

                    if type(SkillsConfig) == "table" and type(SkillsConfig.GetSkillLabel) == "function" then
                        skill_label = SkillsConfig.GetSkillLabel(skill_row.skill_key)
                    end

                    Chat.SendMessage(
                        player,
                        string.format(
                            "- %s niveau %s | XP %s/%s | total %s",
                            tostring(skill_label or skill_row.skill_key),
                            tostring(skill_row.level),
                            tostring(skill_row.current_xp),
                            tostring(required_xp),
                            tostring(skill_row.total_xp)
                        )
                    )
                end
            end)

            return false
        end

        if command_name == "giveskillxp" then
            local is_allowed = false
            local platform_id = nil
            local guard_error = nil
            local skill_key = nil
            local amount_text = nil
            local amount = nil

            is_allowed, platform_id, guard_error = can_use_giveskillxp_command(player)

            if not is_allowed then
                Console.Log(
                    "[gr_skills][server] Give skill XP command denied platform_id=%s reason=%s.",
                    tostring(platform_id),
                    tostring(guard_error)
                )
                Chat.SendMessage(player, "Commande reservee au staff/dev.")
                return false
            end

            if payload == nil then
                Chat.SendMessage(player, "Usage : /giveskillxp <skill_key> <amount>")
                return false
            end

            skill_key, amount_text = payload:match("^(%S+)%s+(%S+)$")
            amount = normalize_positive_integer(amount_text)

            if trim_string(skill_key) == nil or amount == nil then
                Chat.SendMessage(player, "Usage : /giveskillxp <skill_key> <amount>")
                return false
            end

            GRSkills.Server.Service:AddSkillXpToActiveCharacter(player, skill_key, amount, "debug-command", function(is_success, skill_row, error)
                if not is_success then
                    if error == "active-character-missing" then
                        Chat.SendMessage(player, "Aucun personnage actif.")
                        return
                    end

                    if error == "invalid-skill" then
                        Chat.SendMessage(player, "Competence inconnue.")
                        return
                    end

                    if error == "skill-xp-amount-required" then
                        Chat.SendMessage(player, "Usage : /giveskillxp <skill_key> <amount>")
                        return
                    end

                    Chat.SendMessage(player, "Impossible d'ajouter l'XP de competence.")
                    return
                end

                Chat.SendMessage(
                    player,
                    string.format("XP competence ajoutee : %s x%s", tostring(skill_row.skill_key), tostring(amount))
                )
            end)

            return false
        end
    end)
end

Console.Log("[gr_skills][server] Skills package loaded.")
Console.Log("[gr_skills][server] Skills bridge exported.")

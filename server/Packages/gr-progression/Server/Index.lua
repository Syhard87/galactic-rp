Package.Require("../Shared/Index.lua")
Package.Require("../Shared/ProgressionConfig.lua")

local XpRules = Package.Require("XpRules.lua")
local ProgressionRepository = Package.Require("ProgressionRepository.lua")
local ProgressionService = Package.Require("ProgressionService.lua")

GRProgression = GRProgression or {}
GRProgression.Server = GRProgression.Server or {}
local ProgressionConfig = GRProgression.Shared and GRProgression.Shared.ProgressionConfig

local function resolve_database_service()
    if type(GRDatabaseBridge) == "table" and type(GRDatabaseBridge.GetService) == "function" then
        return GRDatabaseBridge.GetService()
    end

    return nil
end

local function callback_service_missing(callback)
    if type(callback) == "function" then
        callback(false, nil, "progression-service-missing")
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

local function get_active_character_from_bridge(player_or_platform_id)
    if type(GRCharactersBridge) ~= "table" or type(GRCharactersBridge.GetActiveCharacter) ~= "function" then
        return nil, "characters-bridge-unavailable"
    end

    local active_character = GRCharactersBridge.GetActiveCharacter(player_or_platform_id)

    if type(active_character) ~= "table" or active_character.id == nil then
        return nil, "active-character-missing"
    end

    return active_character, nil
end

local function extract_faction_name(resolution)
    if type(resolution) ~= "table" then
        return "Aucune"
    end

    if type(resolution.faction) ~= "table" then
        return "Aucune"
    end

    return trim_string(resolution.faction.name) or "Aucune"
end

local function sort_profile_skills(skill_rows)
    table.sort(skill_rows, function(left_skill, right_skill)
        local left_level = tonumber(left_skill and left_skill.level) or 0
        local right_level = tonumber(right_skill and right_skill.level) or 0

        if left_level ~= right_level then
            return left_level > right_level
        end

        local left_total_xp = tonumber(left_skill and left_skill.total_xp) or 0
        local right_total_xp = tonumber(right_skill and right_skill.total_xp) or 0

        if left_total_xp ~= right_total_xp then
            return left_total_xp > right_total_xp
        end

        return tostring(left_skill and left_skill.skill_key) < tostring(right_skill and right_skill.skill_key)
    end)
end

local function send_profile_messages(player, active_character, progression, faction_name, skill_rows)
    local first_name = trim_string(active_character and active_character.first_name) or "Unknown"
    local last_name = trim_string(active_character and active_character.last_name) or "Character"
    local level = tonumber(progression and progression.level) or 1
    local current_xp = tonumber(progression and progression.current_xp) or 0
    local total_xp = tonumber(progression and progression.total_xp) or 0
    local unspent_talent_points = tonumber(progression and progression.unspent_talent_points) or 0
    local class_key = trim_string(progression and progression.class_key) or "civilian"
    local required_xp = XpRules.GetRequiredXpForLevel(level)
    local limited_skill_count = math.min(#skill_rows, 5)

    Chat.SendMessage(player, "Profil personnage")
    Chat.SendMessage(player, string.format("Nom : %s %s", first_name, last_name))
    Chat.SendMessage(player, string.format("Classe : %s", class_key))
    Chat.SendMessage(player, string.format("Niveau : %s", tostring(level)))
    Chat.SendMessage(player, string.format("XP : %s/%s | Total : %s", tostring(current_xp), tostring(required_xp), tostring(total_xp)))
    Chat.SendMessage(player, string.format("Points de talent : %s", tostring(unspent_talent_points)))
    Chat.SendMessage(player, string.format("Faction : %s", tostring(faction_name or "Aucune")))

    if limited_skill_count < 1 then
        Chat.SendMessage(player, "Competences : aucune")
        return
    end

    Chat.SendMessage(player, "Competences :")

    for index = 1, limited_skill_count do
        local skill_row = skill_rows[index]
        local skill_level = tonumber(skill_row and skill_row.level) or 1
        local skill_required_xp = SkillXpRules.GetRequiredXpForLevel(skill_level)

        Chat.SendMessage(
            player,
            string.format(
                "- %s niveau %s | XP %s/%s | total %s",
                tostring(skill_row and skill_row.skill_key),
                tostring(skill_level),
                tostring(skill_row and skill_row.current_xp or 0),
                tostring(skill_required_xp),
                tostring(skill_row and skill_row.total_xp or 0)
            )
        )
    end
end

local function handle_profile_command(player)
    local active_character = nil
    local character_error = nil

    active_character, character_error = get_active_character_from_bridge(player)

    if active_character == nil then
        Chat.SendMessage(player, "Aucun personnage actif.")
        return false
    end

    GRProgression.Server.Service:GetActiveCharacterProgression(player, function(is_progression_success, progression, progression_error)
        if not is_progression_success then
            if progression_error == "active-character-missing" then
                Chat.SendMessage(player, "Aucun personnage actif.")
                return
            end

            Chat.SendMessage(player, "Impossible de charger la progression.")
            return
        end

        local function resolve_skills_and_send_profile(faction_name)
            if type(GRSkillsBridge) ~= "table" or type(GRSkillsBridge.ListActiveCharacterSkills) ~= "function" then
                send_profile_messages(player, active_character, progression, faction_name, {})
                return
            end

            GRSkillsBridge.ListActiveCharacterSkills(player, function(is_skills_success, skill_rows, skills_error)
                if not is_skills_success then
                    if skills_error == "active-character-missing" then
                        Chat.SendMessage(player, "Aucun personnage actif.")
                        return
                    end

                    Chat.SendMessage(player, "Impossible de charger les competences.")
                    return
                end

                skill_rows = type(skill_rows) == "table" and skill_rows or {}
                sort_profile_skills(skill_rows)
                send_profile_messages(player, active_character, progression, faction_name, skill_rows)
            end)
        end

        if type(GRFactionsBridge) ~= "table" or type(GRFactionsBridge.ResolveActiveCharacterFaction) ~= "function" then
            resolve_skills_and_send_profile("Aucune")
            return
        end

        GRFactionsBridge.ResolveActiveCharacterFaction(player, function(is_faction_success, resolution)
            if not is_faction_success then
                resolve_skills_and_send_profile("Aucune")
                return
            end

            resolve_skills_and_send_profile(extract_faction_name(resolution))
        end)
    end)

    return false
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

local function can_use_givexp_command(player_or_platform_id)
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

    debug_commands_enabled = normalize_boolean(custom_settings.gr_progression_debug_commands_enabled, false)

    if not debug_commands_enabled then
        return false, platform_id, "debug-disabled"
    end

    allowlist, has_allowlist_entries = parse_platform_id_allowlist(custom_settings.gr_progression_debug_allowed_platform_ids)

    if not has_allowlist_entries then
        return false, platform_id, "allowlist-missing"
    end

    if allowlist[platform_id] ~= true then
        return false, platform_id, "not-authorized"
    end

    return true, platform_id, nil
end

local database_service = resolve_database_service()

GRProgression.Server.Repository = ProgressionRepository.Create(database_service)
GRProgression.Server.Service = ProgressionService.Create(GRProgression.Server.Repository)

if database_service ~= nil then
    Console.Log("[gr_progression][server] Database service resolved through GRDatabaseBridge.")
else
    Console.Log("[gr_progression][server] Database service unavailable because GRDatabaseBridge is missing.")
end

local GRProgressionBridge = {
    GetService = function()
        return GRProgression.Server.Service
    end,
    GetOrCreateProgression = function(character_id, class_key, callback)
        if GRProgression.Server.Service == nil then
            return callback_service_missing(callback)
        end

        return GRProgression.Server.Service:GetOrCreateProgression(character_id, class_key, callback)
    end,
    GetActiveCharacterProgression = function(player_or_platform_id, callback)
        if GRProgression.Server.Service == nil then
            return callback_service_missing(callback)
        end

        return GRProgression.Server.Service:GetActiveCharacterProgression(player_or_platform_id, callback)
    end,
    AddXp = function(character_id, amount, reason, callback)
        if GRProgression.Server.Service == nil then
            return callback_service_missing(callback)
        end

        return GRProgression.Server.Service:AddXp(character_id, amount, reason, callback)
    end,
    AddXpToActiveCharacter = function(player_or_platform_id, amount, reason, callback)
        if GRProgression.Server.Service == nil then
            return callback_service_missing(callback)
        end

        return GRProgression.Server.Service:AddXpToActiveCharacter(player_or_platform_id, amount, reason, callback)
    end,
    SetClass = function(character_id, class_key, callback)
        if GRProgression.Server.Service == nil then
            return callback_service_missing(callback)
        end

        return GRProgression.Server.Service:SetClass(character_id, class_key, callback)
    end,
    SetActiveCharacterClass = function(player_or_platform_id, class_key, callback)
        if GRProgression.Server.Service == nil then
            return callback_service_missing(callback)
        end

        return GRProgression.Server.Service:SetActiveCharacterClass(player_or_platform_id, class_key, callback)
    end,
}

Package.Export("GRProgressionBridge", GRProgressionBridge)

if type(Chat) == "table" and type(Chat.Subscribe) == "function" and type(Chat.SendMessage) == "function" then
    Chat.Subscribe("PlayerSubmit", function(first_argument, second_argument)
        local player, message = normalize_chat_submit_arguments(first_argument, second_argument)
        local command_name = nil
        local payload = nil

        if player == nil then
            return
        end

        command_name, payload = get_chat_command(message)

        if command_name == "profile" then
            return handle_profile_command(player)
        end

        if command_name == "xpinfo" then
            GRProgression.Server.Service:GetActiveCharacterProgression(player, function(is_success, progression, error)
                local required_xp = nil

                if not is_success then
                    if error == "active-character-missing" then
                        Chat.SendMessage(player, "Aucun personnage actif.")
                        return
                    end

                    Chat.SendMessage(player, "Progression indisponible.")
                    return
                end

                required_xp = XpRules.GetRequiredXpForLevel(progression.level)

                Chat.SendMessage(
                    player,
                    string.format(
                        "Progression : niveau %s | XP %s/%s | total %s | classe %s",
                        tostring(progression.level),
                        tostring(progression.current_xp),
                        tostring(required_xp),
                        tostring(progression.total_xp),
                        tostring(progression.class_key)
                    )
                )
            end)

            return false
        end

        if command_name == "classes" then
            local classes = nil

            if type(ProgressionConfig) ~= "table" or type(ProgressionConfig.ListClasses) ~= "function" then
                Chat.SendMessage(player, "Classes indisponibles.")
                return false
            end

            classes = ProgressionConfig.ListClasses()

            Chat.SendMessage(player, "Classes disponibles :")

            for _, class_definition in ipairs(classes) do
                Chat.SendMessage(
                    player,
                    string.format("- %s : %s", tostring(class_definition.key), tostring(class_definition.label))
                )
            end

            return false
        end

        if command_name == "setclass" then
            local class_key = trim_string(payload)

            if class_key == nil or class_key:find("%s") ~= nil then
                Chat.SendMessage(player, "Usage : /setclass <class_key>")
                return false
            end

            GRProgression.Server.Service:SetActiveCharacterClass(player, class_key, function(is_success, progression, error)
                if not is_success then
                    if error == "active-character-missing" then
                        Chat.SendMessage(player, "Aucun personnage actif.")
                        return
                    end

                    if error == "invalid-class" then
                        Chat.SendMessage(player, "Classe inconnue.")
                        return
                    end

                    Chat.SendMessage(player, "Impossible de definir la classe.")
                    return
                end

                Chat.SendMessage(player, string.format("Classe definie : %s", tostring(progression.class_key)))
            end)

            return false
        end

        if command_name == "givexp" then
            local is_allowed = false
            local platform_id = nil
            local guard_error = nil
            local amount = nil

            is_allowed, platform_id, guard_error = can_use_givexp_command(player)

            if not is_allowed then
                Console.Log(
                    "[gr_progression][server] Give XP command denied platform_id=%s reason=%s.",
                    tostring(platform_id),
                    tostring(guard_error)
                )
                Chat.SendMessage(player, "Commande reservee au staff/dev.")
                return false
            end

            amount = normalize_positive_integer(payload)

            if amount == nil then
                Chat.SendMessage(player, "Usage : /givexp <amount>")
                return false
            end

            GRProgression.Server.Service:AddXpToActiveCharacter(player, amount, "debug-command", function(is_success, _, error)
                if not is_success then
                    if error == "active-character-missing" then
                        Chat.SendMessage(player, "Aucun personnage actif.")
                        return
                    end

                    if error == "xp-amount-required" then
                        Chat.SendMessage(player, "Usage : /givexp <amount>")
                        return
                    end

                    Chat.SendMessage(player, "Impossible d'ajouter l'XP.")
                    return
                end

                Chat.SendMessage(player, string.format("XP ajoutee : %s", tostring(amount)))
            end)

            return false
        end
    end)
end

Console.Log("[gr_progression][server] Progression package loaded.")
Console.Log("[gr_progression][server] Progression bridge exported.")

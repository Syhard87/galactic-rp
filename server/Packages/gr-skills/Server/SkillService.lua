GRSkills = GRSkills or {}
GRSkills.Server = GRSkills.Server or {}

local SkillsConfig = GRSkills.Shared and GRSkills.Shared.SkillsConfig
local SkillXpRules = GRSkills.Server and GRSkills.Server.SkillXpRules

local SkillService = {}
SkillService.__index = SkillService

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

local function normalize_skill_key(skill_key)
    if type(SkillsConfig) == "table" and type(SkillsConfig.NormalizeSkillKey) == "function" then
        return SkillsConfig.NormalizeSkillKey(skill_key)
    end

    return trim_string(skill_key)
end

local function normalize_class_key(class_key)
    local trimmed_class_key = trim_string(class_key)

    if trimmed_class_key == nil then
        return nil
    end

    return string.lower(trimmed_class_key)
end

local function get_required_xp_for_level(level)
    if type(SkillXpRules) == "table" and type(SkillXpRules.GetRequiredXpForLevel) == "function" then
        return SkillXpRules.GetRequiredXpForLevel(level)
    end

    return (normalize_positive_integer(level) or 1) * 75
end

local function get_max_level()
    if type(SkillsConfig) == "table" and type(SkillsConfig.MAX_LEVEL) == "number" then
        return SkillsConfig.MAX_LEVEL
    end

    return 20
end

local function calculate_general_xp_from_skill_xp(skill_xp_amount)
    local normalized_amount = normalize_positive_integer(skill_xp_amount)
    local general_xp_amount = 0

    if normalized_amount == nil then
        return nil
    end

    general_xp_amount = math.floor(normalized_amount * 0.25)

    if general_xp_amount < 1 and normalized_amount > 0 then
        general_xp_amount = 1
    end

    return general_xp_amount
end

local CLASS_SKILL_BONUS_MAP = {
    military_recruit = {
        light_weapons = true,
    },
    medic = {
        medicine = true,
    },
    engineer = {
        mechanics = true,
        crafting = true,
    },
    merchant = {
        commerce = true,
    },
    smuggler = {
        smuggling = true,
    },
    explorer = {
        exploration = true,
        survival = true,
    },
}

local function get_class_skill_bonus_percent(class_key, skill_key)
    local normalized_class_key = normalize_class_key(class_key)
    local normalized_skill_key = normalize_skill_key(skill_key)
    local class_bonus_skills = nil

    if normalized_class_key == nil or normalized_skill_key == nil then
        return 0
    end

    if normalized_class_key == "civilian" then
        return 0
    end

    class_bonus_skills = CLASS_SKILL_BONUS_MAP[normalized_class_key]

    if type(class_bonus_skills) ~= "table" or class_bonus_skills[normalized_skill_key] ~= true then
        return 0
    end

    return 10
end

local function apply_class_skill_xp_bonus(base_amount, class_key, skill_key)
    local normalized_amount = normalize_positive_integer(base_amount)
    local bonus_percent = get_class_skill_bonus_percent(class_key, skill_key)
    local final_amount = 0

    if normalized_amount == nil then
        return nil, bonus_percent
    end

    if bonus_percent <= 0 then
        return normalized_amount, 0
    end

    final_amount = math.floor(normalized_amount * (1 + (bonus_percent / 100)))

    if final_amount <= normalized_amount then
        final_amount = normalized_amount + 1
    end

    return final_amount, bonus_percent
end

local function current_utc_timestamp()
    return os.date("!%Y-%m-%dT%H:%M:%SZ")
end

local function resolve_active_character_id(player_or_platform_id)
    local active_character = nil

    if type(GRCharactersBridge) ~= "table" or type(GRCharactersBridge.GetActiveCharacter) ~= "function" then
        return nil, "characters-bridge-unavailable"
    end

    active_character = GRCharactersBridge.GetActiveCharacter(player_or_platform_id)

    if type(active_character) ~= "table" or active_character.id == nil then
        return nil, "active-character-missing"
    end

    return active_character.id, nil
end

local function callback_repository_missing(callback)
    if type(callback) == "function" then
        callback(false, nil, "skill-repository-missing")
    end

    return true
end

local function grant_general_xp_from_skill_xp(character_id, skill_key, skill_xp_amount, callback)
    local general_xp_amount = calculate_general_xp_from_skill_xp(skill_xp_amount)
    local reason = nil

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if general_xp_amount == nil then
        callback(false, "general-xp-amount-required")
        return true
    end

    if type(GRProgressionBridge) ~= "table" or type(GRProgressionBridge.AddXp) ~= "function" then
        Console.Log("[gr_skills][service] General XP skipped reason=progression-bridge-unavailable.")
        callback(false, "progression-bridge-unavailable")
        return true
    end

    reason = string.format("skill-xp:%s", tostring(skill_key))

    return GRProgressionBridge.AddXp(character_id, general_xp_amount, reason, function(is_success, _, error)
        if not is_success then
            Console.Log(
                "[gr_skills][service] General XP grant failed character_id=%s skill_key=%s reason=%s.",
                tostring(character_id),
                tostring(skill_key),
                tostring(error)
            )
            callback(false, error)
            return
        end

        Console.Log(
            "[gr_skills][service] General XP granted from skill XP character_id=%s skill_key=%s skill_xp=%s general_xp=%s.",
            tostring(character_id),
            tostring(skill_key),
            tostring(skill_xp_amount),
            tostring(general_xp_amount)
        )
        callback(true, nil)
    end)
end

local function resolve_final_skill_xp_amount(character_id, skill_key, base_amount, callback)
    local normalized_character_id = normalize_positive_integer(character_id)
    local normalized_skill_key = normalize_skill_key(skill_key)
    local normalized_base_amount = normalize_positive_integer(base_amount)

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if normalized_character_id == nil then
        callback(false, nil, "character-id-required")
        return true
    end

    if normalized_skill_key == nil then
        callback(false, nil, "invalid-skill")
        return true
    end

    if normalized_base_amount == nil then
        callback(false, nil, "skill-xp-amount-required")
        return true
    end

    if type(GRProgressionBridge) ~= "table" or type(GRProgressionBridge.GetOrCreateProgression) ~= "function" then
        Console.Log("[gr_skills][service] Class skill XP bonus skipped reason=progression-bridge-unavailable.")
        callback(true, normalized_base_amount, nil)
        return true
    end

    return GRProgressionBridge.GetOrCreateProgression(normalized_character_id, "civilian", function(is_success, progression, error)
        local class_key = nil
        local final_amount = nil
        local bonus_percent = 0

        if not is_success then
            Console.Log(
                "[gr_skills][service] Class skill XP bonus skipped reason=%s.",
                tostring(error or "progression-load-failed")
            )
            callback(true, normalized_base_amount, nil)
            return
        end

        class_key = type(progression) == "table" and progression.class_key or "civilian"
        final_amount, bonus_percent = apply_class_skill_xp_bonus(normalized_base_amount, class_key, normalized_skill_key)

        if final_amount == nil then
            callback(false, nil, "skill-xp-amount-required")
            return
        end

        if bonus_percent > 0 and final_amount > normalized_base_amount then
            Console.Log(
                "[gr_skills][service] Class skill XP bonus applied character_id=%s class_key=%s skill_key=%s base_xp=%s final_xp=%s.",
                tostring(normalized_character_id),
                tostring(class_key),
                tostring(normalized_skill_key),
                tostring(normalized_base_amount),
                tostring(final_amount)
            )
        else
            Console.Log(
                "[gr_skills][service] Skill XP has no class bonus character_id=%s class_key=%s skill_key=%s amount=%s.",
                tostring(normalized_character_id),
                tostring(class_key),
                tostring(normalized_skill_key),
                tostring(normalized_base_amount)
            )
        end

        callback(true, final_amount, nil)
    end)
end

function SkillService.Create(repository)
    local self = setmetatable({}, SkillService)

    self.repository = repository

    return self
end

function SkillService:ListSkills(character_id, callback)
    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if self.repository == nil then
        return callback_repository_missing(callback)
    end

    return self.repository:ListSkills(character_id, callback)
end

function SkillService:ListActiveCharacterSkills(player_or_platform_id, callback)
    local active_character_id = nil
    local resolve_error = nil

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if self.repository == nil then
        return callback_repository_missing(callback)
    end

    active_character_id, resolve_error = resolve_active_character_id(player_or_platform_id)

    if active_character_id == nil then
        callback(false, nil, resolve_error)
        return true
    end

    return self.repository:ListSkills(active_character_id, callback)
end

function SkillService:AddSkillXp(character_id, skill_key, amount, reason, callback)
    local normalized_character_id = normalize_positive_integer(character_id)
    local normalized_skill_key = normalize_skill_key(skill_key)
    local normalized_amount = normalize_positive_integer(amount)
    local normalized_reason = trim_string(reason) or "unspecified"
    local max_level = get_max_level()

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if self.repository == nil then
        return callback_repository_missing(callback)
    end

    if normalized_character_id == nil then
        callback(false, nil, "character-id-required")
        return true
    end

    if normalized_skill_key == nil then
        callback(false, nil, "invalid-skill")
        return true
    end

    if normalized_amount == nil then
        callback(false, nil, "skill-xp-amount-required")
        return true
    end

    return resolve_final_skill_xp_amount(normalized_character_id, normalized_skill_key, normalized_amount, function(is_resolved, final_skill_xp_amount, resolve_error)
        if not is_resolved then
            callback(false, nil, resolve_error)
            return
        end

        self.repository:GetOrCreateSkill(normalized_character_id, normalized_skill_key, function(is_success, skill_row, error)
            local required_xp = nil

            if not is_success then
                callback(false, nil, error)
                return
            end

            skill_row.current_xp = (skill_row.current_xp or 0) + final_skill_xp_amount
            skill_row.total_xp = (skill_row.total_xp or 0) + final_skill_xp_amount
            skill_row.last_gain_at = current_utc_timestamp()

            Console.Log(
                "[gr_skills][service] Skill XP added character_id=%s skill_key=%s amount=%s reason=%s.",
                tostring(normalized_character_id),
                tostring(normalized_skill_key),
                tostring(final_skill_xp_amount),
                tostring(normalized_reason)
            )

            while skill_row.level < max_level do
                required_xp = get_required_xp_for_level(skill_row.level)

                if skill_row.current_xp < required_xp then
                    break
                end

                skill_row.current_xp = skill_row.current_xp - required_xp
                skill_row.level = skill_row.level + 1

                Console.Log(
                    "[gr_skills][service] Skill level up character_id=%s skill_key=%s new_level=%s.",
                    tostring(normalized_character_id),
                    tostring(normalized_skill_key),
                    tostring(skill_row.level)
                )
            end

            if skill_row.level >= max_level then
                skill_row.level = max_level
                skill_row.current_xp = math.min(skill_row.current_xp, get_required_xp_for_level(max_level))
            end

            self.repository:SaveSkill(skill_row, function(is_save_success, saved_skill_row, save_error)
                if not is_save_success then
                    callback(false, nil, save_error)
                    return
                end

                grant_general_xp_from_skill_xp(
                    normalized_character_id,
                    normalized_skill_key,
                    final_skill_xp_amount,
                    function() end
                )

                callback(true, saved_skill_row, nil)
            end)
        end)
    end)
end

function SkillService:AddSkillXpToActiveCharacter(player_or_platform_id, skill_key, amount, reason, callback)
    local active_character_id = nil
    local resolve_error = nil

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if self.repository == nil then
        return callback_repository_missing(callback)
    end

    active_character_id, resolve_error = resolve_active_character_id(player_or_platform_id)

    if active_character_id == nil then
        callback(false, nil, resolve_error)
        return true
    end

    return self:AddSkillXp(active_character_id, skill_key, amount, reason, callback)
end

GRSkills.Server.SkillServiceClass = SkillService

return SkillService

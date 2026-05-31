GRProgression = GRProgression or {}
GRProgression.Server = GRProgression.Server or {}

local ProgressionConfig = GRProgression.Shared and GRProgression.Shared.ProgressionConfig
local XpRules = GRProgression.Server and GRProgression.Server.XpRules

local ProgressionService = {}
ProgressionService.__index = ProgressionService

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

local function normalize_class_key(class_key)
    if type(ProgressionConfig) == "table" and type(ProgressionConfig.NormalizeClassKey) == "function" then
        return ProgressionConfig.NormalizeClassKey(class_key)
    end

    return trim_string(class_key) or "civilian"
end

local function get_max_level()
    if type(ProgressionConfig) == "table" and type(ProgressionConfig.MAX_LEVEL) == "number" then
        return ProgressionConfig.MAX_LEVEL
    end

    return 20
end

local function get_required_xp_for_level(level)
    if type(XpRules) == "table" and type(XpRules.GetRequiredXpForLevel) == "function" then
        return XpRules.GetRequiredXpForLevel(level)
    end

    return (normalize_positive_integer(level) or 1) * 100
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
        callback(false, nil, "progression-repository-missing")
    end

    return true
end

function ProgressionService.Create(repository)
    local self = setmetatable({}, ProgressionService)

    self.repository = repository

    return self
end

function ProgressionService:GetOrCreateProgression(character_id, class_key, callback)
    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if self.repository == nil then
        return callback_repository_missing(callback)
    end

    return self.repository:GetOrCreate(character_id, normalize_class_key(class_key), callback)
end

function ProgressionService:GetActiveCharacterProgression(player_or_platform_id, callback)
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

    return self:GetOrCreateProgression(active_character_id, nil, callback)
end

function ProgressionService:AddXp(character_id, amount, reason, callback)
    local normalized_character_id = normalize_positive_integer(character_id)
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

    if normalized_amount == nil then
        callback(false, nil, "xp-amount-required")
        return true
    end

    return self:GetOrCreateProgression(normalized_character_id, nil, function(is_success, progression, error)
        local required_xp = nil

        if not is_success then
            callback(false, nil, error)
            return
        end

        progression.current_xp = (progression.current_xp or 0) + normalized_amount
        progression.total_xp = (progression.total_xp or 0) + normalized_amount

        Console.Log(
            "[gr_progression][service] XP added character_id=%s amount=%s reason=%s.",
            tostring(normalized_character_id),
            tostring(normalized_amount),
            tostring(normalized_reason)
        )

        while progression.level < max_level do
            required_xp = get_required_xp_for_level(progression.level)

            if progression.current_xp < required_xp then
                break
            end

            progression.current_xp = progression.current_xp - required_xp
            progression.level = progression.level + 1
            progression.unspent_talent_points = (progression.unspent_talent_points or 0) + 1

            Console.Log(
                "[gr_progression][service] Level up character_id=%s new_level=%s.",
                tostring(normalized_character_id),
                tostring(progression.level)
            )
        end

        if progression.level >= max_level then
            progression.level = max_level
            progression.current_xp = math.min(progression.current_xp, get_required_xp_for_level(max_level))
        end

        self.repository:SaveProgression(progression, callback)
    end)
end

function ProgressionService:AddXpToActiveCharacter(player_or_platform_id, amount, reason, callback)
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

    return self:AddXp(active_character_id, amount, reason, callback)
end

GRProgression.Server.ProgressionServiceClass = ProgressionService

return ProgressionService

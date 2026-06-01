GRSkills = GRSkills or {}
GRSkills.Server = GRSkills.Server or {}

local SkillXpRules = {}

local function normalize_level(level)
    if type(level) == "number" and level >= 1 then
        return math.floor(level)
    end

    if type(level) == "string" and level:match("^%d+$") ~= nil then
        local parsed_level = tonumber(level)

        if parsed_level ~= nil and parsed_level >= 1 then
            return math.floor(parsed_level)
        end
    end

    return 1
end

function SkillXpRules.GetRequiredXpForLevel(level)
    local normalized_level = normalize_level(level)

    return normalized_level * 75
end

GRSkills.Server.SkillXpRules = SkillXpRules

return SkillXpRules

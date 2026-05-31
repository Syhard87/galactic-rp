GRProgression = GRProgression or {}
GRProgression.Server = GRProgression.Server or {}

local XpRules = {}

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

function XpRules.GetRequiredXpForLevel(level)
    local normalized_level = normalize_level(level)

    return normalized_level * 100
end

GRProgression.Server.XpRules = XpRules

return XpRules

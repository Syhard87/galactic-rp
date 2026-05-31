GRProgression = GRProgression or {}
GRProgression.Shared = GRProgression.Shared or {}

local ProgressionConfig = {
    MIN_LEVEL = 1,
    MAX_LEVEL = 20,
    FALLBACK_CLASS_KEY = "civilian",
    CLASSES = {
        civilian = true,
        military_recruit = true,
        medic = true,
        engineer = true,
        merchant = true,
        smuggler = true,
        explorer = true,
    },
    ORDERED_CLASSES = {
        "civilian",
        "military_recruit",
        "medic",
        "engineer",
        "merchant",
        "smuggler",
        "explorer",
    },
}

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

function ProgressionConfig.IsValidClassKey(class_key)
    local normalized_class_key = trim_string(class_key)

    if normalized_class_key == nil then
        return false
    end

    return ProgressionConfig.CLASSES[normalized_class_key] == true
end

function ProgressionConfig.NormalizeClassKey(class_key)
    if ProgressionConfig.IsValidClassKey(class_key) then
        return trim_string(class_key)
    end

    return ProgressionConfig.FALLBACK_CLASS_KEY
end

GRProgression.Shared.ProgressionConfig = ProgressionConfig

return ProgressionConfig

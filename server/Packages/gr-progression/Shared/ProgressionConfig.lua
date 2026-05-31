GRProgression = GRProgression or {}
GRProgression.Shared = GRProgression.Shared or {}

local ProgressionConfig = {
    MIN_LEVEL = 1,
    MAX_LEVEL = 20,
    FALLBACK_CLASS_KEY = "civilian",
    CLASSES = {
        civilian = {
            key = "civilian",
            label = "Civil",
            description = "Profil neutre sans specialisation.",
        },
        military_recruit = {
            key = "military_recruit",
            label = "Recrue militaire",
            description = "Combat, discipline et operations.",
        },
        medic = {
            key = "medic",
            label = "Medecin",
            description = "Soin, diagnostic et soutien medical.",
        },
        engineer = {
            key = "engineer",
            label = "Ingenieur",
            description = "Reparation, mecanique et fabrication.",
        },
        merchant = {
            key = "merchant",
            label = "Marchand",
            description = "Commerce, logistique et contrats.",
        },
        smuggler = {
            key = "smuggler",
            label = "Contrebandier",
            description = "Discretion, marche noir et falsification.",
        },
        explorer = {
            key = "explorer",
            label = "Explorateur",
            description = "Exploration, recolte et survie.",
        },
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

local function normalize_class_key_for_lookup(class_key)
    local normalized_class_key = trim_string(class_key)

    if normalized_class_key == nil then
        return nil
    end

    return string.lower(normalized_class_key)
end

function ProgressionConfig.IsValidClassKey(class_key)
    local normalized_class_key = normalize_class_key_for_lookup(class_key)

    if normalized_class_key == nil then
        return false
    end

    return type(ProgressionConfig.CLASSES[normalized_class_key]) == "table"
end

function ProgressionConfig.GetClassByKey(class_key)
    local normalized_class_key = normalize_class_key_for_lookup(class_key)

    if normalized_class_key == nil then
        return nil
    end

    return ProgressionConfig.CLASSES[normalized_class_key]
end

function ProgressionConfig.GetClassLabel(class_key)
    local class_definition = ProgressionConfig.GetClassByKey(class_key)

    if type(class_definition) ~= "table" then
        return nil
    end

    return class_definition.label
end

function ProgressionConfig.ListClasses()
    local classes = {}

    for _, class_key in ipairs(ProgressionConfig.ORDERED_CLASSES) do
        local class_definition = ProgressionConfig.GetClassByKey(class_key)

        if type(class_definition) == "table" then
            classes[#classes + 1] = class_definition
        end
    end

    return classes
end

function ProgressionConfig.NormalizeClassKey(class_key)
    if ProgressionConfig.IsValidClassKey(class_key) then
        return normalize_class_key_for_lookup(class_key)
    end

    return ProgressionConfig.FALLBACK_CLASS_KEY
end

GRProgression.Shared.ProgressionConfig = ProgressionConfig

return ProgressionConfig

GRSkills = GRSkills or {}
GRSkills.Shared = GRSkills.Shared or {}

local SkillsConfig = {
    MAX_LEVEL = 20,
    SKILLS = {
        light_weapons = {
            key = "light_weapons",
            label = "Armes legeres",
            description = "Maitrise des armes legeres et de leur usage.",
        },
        medicine = {
            key = "medicine",
            label = "Medecine",
            description = "Diagnostic, soins et soutien medical.",
        },
        mechanics = {
            key = "mechanics",
            label = "Mecanique",
            description = "Reparation, entretien et technique.",
        },
        commerce = {
            key = "commerce",
            label = "Commerce",
            description = "Negociation, logistique et contrats.",
        },
        smuggling = {
            key = "smuggling",
            label = "Contrebande",
            description = "Discretion, marche noir et transport illicit.",
        },
        exploration = {
            key = "exploration",
            label = "Exploration",
            description = "Reconnaissance, reperage et decouverte.",
        },
        survival = {
            key = "survival",
            label = "Survie",
            description = "Endurance, adaptation et vie en terrain hostile.",
        },
        crafting = {
            key = "crafting",
            label = "Fabrication",
            description = "Assemblage, bricolage et production simple.",
        },
    },
    ORDERED_SKILLS = {
        "light_weapons",
        "medicine",
        "mechanics",
        "commerce",
        "smuggling",
        "exploration",
        "survival",
        "crafting",
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

local function normalize_skill_key_for_lookup(skill_key)
    local normalized_skill_key = trim_string(skill_key)

    if normalized_skill_key == nil then
        return nil
    end

    return string.lower(normalized_skill_key)
end

function SkillsConfig.IsValidSkillKey(skill_key)
    local normalized_skill_key = normalize_skill_key_for_lookup(skill_key)

    if normalized_skill_key == nil then
        return false
    end

    return type(SkillsConfig.SKILLS[normalized_skill_key]) == "table"
end

function SkillsConfig.GetSkillByKey(skill_key)
    local normalized_skill_key = normalize_skill_key_for_lookup(skill_key)

    if normalized_skill_key == nil then
        return nil
    end

    return SkillsConfig.SKILLS[normalized_skill_key]
end

function SkillsConfig.GetSkillLabel(skill_key)
    local skill_definition = SkillsConfig.GetSkillByKey(skill_key)

    if type(skill_definition) ~= "table" then
        return nil
    end

    return skill_definition.label
end

function SkillsConfig.ListSkills()
    local skills = {}

    for _, skill_key in ipairs(SkillsConfig.ORDERED_SKILLS) do
        local skill_definition = SkillsConfig.GetSkillByKey(skill_key)

        if type(skill_definition) == "table" then
            skills[#skills + 1] = skill_definition
        end
    end

    return skills
end

function SkillsConfig.NormalizeSkillKey(skill_key)
    if SkillsConfig.IsValidSkillKey(skill_key) then
        return normalize_skill_key_for_lookup(skill_key)
    end

    return nil
end

GRSkills.Shared.SkillsConfig = SkillsConfig

return SkillsConfig

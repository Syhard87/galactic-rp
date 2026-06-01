GRQuests = GRQuests or {}
GRQuests.Shared = GRQuests.Shared or {}

local QuestConfig = {
    STATUSES = {
        started = true,
        completed = true,
        abandoned = true,
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

function QuestConfig.IsValidQuestStatus(status)
    local normalized_status = trim_string(status)

    if normalized_status == nil then
        return false
    end

    return QuestConfig.STATUSES[string.lower(normalized_status)] == true
end

function QuestConfig.NormalizeQuestKey(quest_key)
    local normalized_quest_key = trim_string(quest_key)

    if normalized_quest_key == nil then
        return nil
    end

    return string.lower(normalized_quest_key)
end

GRQuests.Shared.QuestConfig = QuestConfig

return QuestConfig

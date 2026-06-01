GRSkills = GRSkills or {}
GRSkills.Server = GRSkills.Server or {}

local SkillsConfig = GRSkills.Shared and GRSkills.Shared.SkillsConfig

local SkillRepository = {}
SkillRepository.__index = SkillRepository

local SELECT_SKILL_QUERY = [[
    SELECT
        character_id,
        skill_key,
        level,
        COALESCE(current_xp, xp, 0) AS current_xp,
        COALESCE(total_xp, xp, 0) AS total_xp,
        last_gain_at,
        created_at,
        updated_at
    FROM character_skills
    WHERE character_id = :0 AND skill_key = :1
    LIMIT 1
]]

local SELECT_SKILLS_BY_CHARACTER_QUERY = [[
    SELECT
        character_id,
        skill_key,
        level,
        COALESCE(current_xp, xp, 0) AS current_xp,
        COALESCE(total_xp, xp, 0) AS total_xp,
        last_gain_at,
        created_at,
        updated_at
    FROM character_skills
    WHERE character_id = :0
    ORDER BY skill_key ASC
]]

local INSERT_DEFAULT_SKILL_QUERY = [[
    INSERT INTO character_skills (
        character_id,
        skill_key
    )
    VALUES (
        :0,
        :1
    )
    ON CONFLICT (character_id, skill_key) DO NOTHING
]]

local UPDATE_SKILL_QUERY = [[
    UPDATE character_skills
    SET
        level = :0,
        current_xp = :1,
        total_xp = :2,
        xp = :3,
        last_gain_at = :4,
        updated_at = NOW()
    WHERE character_id = :5 AND skill_key = :6
]]

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

local function normalize_non_negative_integer(value, fallback)
    if type(value) == "number" then
        if value < 0 then
            return fallback
        end

        return math.floor(value)
    end

    if type(value) == "string" and value:match("^%d+$") ~= nil then
        local parsed_value = tonumber(value)

        if parsed_value ~= nil and parsed_value >= 0 then
            return math.floor(parsed_value)
        end
    end

    return fallback
end

local function normalize_skill_key(skill_key)
    if type(SkillsConfig) == "table" and type(SkillsConfig.NormalizeSkillKey) == "function" then
        return SkillsConfig.NormalizeSkillKey(skill_key)
    end

    return trim_string(skill_key)
end

local function normalize_skill_row(row)
    local character_id = nil
    local skill_key = nil

    if type(row) ~= "table" then
        return nil
    end

    character_id = normalize_positive_integer(row.character_id)
    skill_key = normalize_skill_key(row.skill_key)

    if character_id == nil or skill_key == nil then
        return nil
    end

    return {
        character_id = character_id,
        skill_key = skill_key,
        level = normalize_positive_integer(row.level) or 1,
        current_xp = normalize_non_negative_integer(row.current_xp, 0),
        total_xp = normalize_non_negative_integer(row.total_xp, 0),
        last_gain_at = trim_string(row.last_gain_at) or row.last_gain_at,
        created_at = row.created_at,
        updated_at = row.updated_at,
    }
end

function SkillRepository.Create(database_service)
    local self = setmetatable({}, SkillRepository)

    self.database_service = database_service

    return self
end

function SkillRepository:Connect(callback, reason)
    local is_connected = false
    local database_or_error = nil

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if self.database_service == nil then
        Console.Log(
            "[gr_skills][repository] Database service unavailable during %s.",
            tostring(reason or "skill-call")
        )
        callback(false, nil, "database-service-missing")
        return true
    end

    is_connected, database_or_error = self.database_service:Connect()

    if not is_connected then
        Console.Log(
            "[gr_skills][repository] Database connection failed during %s with error=%s.",
            tostring(reason or "skill-call"),
            tostring(database_or_error)
        )
        callback(false, nil, database_or_error)
        return true
    end

    callback(true, database_or_error, nil)
    return true
end

function SkillRepository:GetSkill(character_id, skill_key, callback)
    local normalized_character_id = normalize_positive_integer(character_id)
    local normalized_skill_key = normalize_skill_key(skill_key)

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

    return self:Connect(function(is_connected, database_or_error, error)
        if not is_connected then
            callback(false, nil, error)
            return
        end

        database_or_error:SelectAsync(SELECT_SKILL_QUERY, function(rows, select_error)
            local skill_row = nil

            if select_error ~= nil then
                Console.Log(
                    "[gr_skills][repository] Skill load failed character_id=%s skill_key=%s error=%s.",
                    tostring(normalized_character_id),
                    tostring(normalized_skill_key),
                    tostring(select_error)
                )
                callback(false, nil, select_error)
                return
            end

            if type(rows) == "table" and rows[1] ~= nil then
                skill_row = normalize_skill_row(rows[1])
            end

            if skill_row ~= nil then
                Console.Log(
                    "[gr_skills][repository] Skill loaded character_id=%s skill_key=%s level=%s.",
                    tostring(skill_row.character_id),
                    tostring(skill_row.skill_key),
                    tostring(skill_row.level)
                )
            end

            callback(true, skill_row, nil)
        end, normalized_character_id, normalized_skill_key)
    end, "skill-get")
end

function SkillRepository:CreateDefault(character_id, skill_key, callback)
    local normalized_character_id = normalize_positive_integer(character_id)
    local normalized_skill_key = normalize_skill_key(skill_key)

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

    return self:Connect(function(is_connected, database_or_error, error)
        if not is_connected then
            callback(false, nil, error)
            return
        end

        database_or_error:ExecuteAsync(INSERT_DEFAULT_SKILL_QUERY, function(_, execute_error)
            if execute_error ~= nil then
                Console.Log(
                    "[gr_skills][repository] Default skill create failed character_id=%s skill_key=%s error=%s.",
                    tostring(normalized_character_id),
                    tostring(normalized_skill_key),
                    tostring(execute_error)
                )
                callback(false, nil, execute_error)
                return
            end

            Console.Log(
                "[gr_skills][repository] Default skill created character_id=%s skill_key=%s.",
                tostring(normalized_character_id),
                tostring(normalized_skill_key)
            )

            self:GetSkill(normalized_character_id, normalized_skill_key, callback)
        end, normalized_character_id, normalized_skill_key)
    end, "skill-create-default")
end

function SkillRepository:GetOrCreateSkill(character_id, skill_key, callback)
    local normalized_character_id = normalize_positive_integer(character_id)
    local normalized_skill_key = normalize_skill_key(skill_key)

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

    return self:GetSkill(normalized_character_id, normalized_skill_key, function(is_success, skill_row, error)
        if not is_success then
            callback(false, nil, error)
            return
        end

        if skill_row ~= nil then
            callback(true, skill_row, nil)
            return
        end

        self:CreateDefault(normalized_character_id, normalized_skill_key, callback)
    end)
end

function SkillRepository:ListSkills(character_id, callback)
    local normalized_character_id = normalize_positive_integer(character_id)

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if normalized_character_id == nil then
        callback(false, nil, "character-id-required")
        return true
    end

    return self:Connect(function(is_connected, database_or_error, error)
        if not is_connected then
            callback(false, nil, error)
            return
        end

        database_or_error:SelectAsync(SELECT_SKILLS_BY_CHARACTER_QUERY, function(rows, select_error)
            local skills = {}

            if select_error ~= nil then
                Console.Log(
                    "[gr_skills][repository] Skills list failed character_id=%s error=%s.",
                    tostring(normalized_character_id),
                    tostring(select_error)
                )
                callback(false, nil, select_error)
                return
            end

            for _, row in ipairs(rows or {}) do
                local normalized_row = normalize_skill_row(row)

                if normalized_row ~= nil then
                    skills[#skills + 1] = normalized_row
                end
            end

            callback(true, skills, nil)
        end, normalized_character_id)
    end, "skills-list")
end

function SkillRepository:SaveSkill(skill_row, callback)
    local normalized_skill_row = normalize_skill_row(skill_row)

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if normalized_skill_row == nil then
        callback(false, nil, "skill-row-required")
        return true
    end

    return self:Connect(function(is_connected, database_or_error, error)
        if not is_connected then
            callback(false, nil, error)
            return
        end

        database_or_error:ExecuteAsync(UPDATE_SKILL_QUERY, function(_, execute_error)
            if execute_error ~= nil then
                Console.Log(
                    "[gr_skills][repository] Skill save failed character_id=%s skill_key=%s error=%s.",
                    tostring(normalized_skill_row.character_id),
                    tostring(normalized_skill_row.skill_key),
                    tostring(execute_error)
                )
                callback(false, nil, execute_error)
                return
            end

            Console.Log(
                "[gr_skills][repository] Skill saved character_id=%s skill_key=%s level=%s current_xp=%s total_xp=%s.",
                tostring(normalized_skill_row.character_id),
                tostring(normalized_skill_row.skill_key),
                tostring(normalized_skill_row.level),
                tostring(normalized_skill_row.current_xp),
                tostring(normalized_skill_row.total_xp)
            )

            callback(true, normalized_skill_row, nil)
        end,
            normalized_skill_row.level,
            normalized_skill_row.current_xp,
            normalized_skill_row.total_xp,
            normalized_skill_row.current_xp,
            normalized_skill_row.last_gain_at,
            normalized_skill_row.character_id,
            normalized_skill_row.skill_key
        )
    end, "skill-save")
end

GRSkills.Server.SkillRepositoryClass = SkillRepository

return SkillRepository

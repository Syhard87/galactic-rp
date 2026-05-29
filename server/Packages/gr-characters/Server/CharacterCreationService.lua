GRCharacters = GRCharacters or {}
GRCharacters.Server = GRCharacters.Server or {}

local CharacterCreationService = {}
CharacterCreationService.__index = CharacterCreationService

local ALLOWED_FIELDS = {
    first_name = true,
    last_name = true,
    age = true,
    species = true,
    biography = true,
}

local MAX_NAME_LENGTH = 64
local MAX_SPECIES_LENGTH = 64
local MAX_BIOGRAPHY_LENGTH = 280
local MIN_AGE = 16
local MAX_AGE = 120

local function clone_table(source)
    if type(source) ~= "table" then
        return nil
    end

    local copy = {}

    for key, value in pairs(source) do
        copy[key] = value
    end

    return copy
end

local function trim_string(value)
    if type(value) ~= "string" then
        return nil
    end

    return value:match("^%s*(.-)%s*$")
end

local function normalize_player_row_id(player_or_row)
    if type(player_or_row) == "number" then
        if player_or_row < 1 then
            return nil
        end

        return math.floor(player_or_row)
    end

    if type(player_or_row) == "string" then
        local parsed_id = tonumber(player_or_row)

        if parsed_id == nil or parsed_id < 1 then
            return nil
        end

        return math.floor(parsed_id)
    end

    if type(player_or_row) ~= "table" and type(player_or_row) ~= "userdata" then
        return nil
    end

    if player_or_row.player_id ~= nil then
        return normalize_player_row_id(player_or_row.player_id)
    end

    if player_or_row.id ~= nil then
        return normalize_player_row_id(player_or_row.id)
    end

    return nil
end

local function normalize_age(value)
    if type(value) == "number" then
        if value % 1 ~= 0 then
            return nil
        end

        return value
    end

    if type(value) == "string" then
        if value:match("^%d+$") == nil then
            return nil
        end

        local parsed_number = tonumber(value)

        if parsed_number == nil or parsed_number % 1 ~= 0 then
            return nil
        end

        return parsed_number
    end

    return nil
end

function CharacterCreationService.Create(repository)
    local self = setmetatable({}, CharacterCreationService)

    self.repository = repository

    return self
end

function CharacterCreationService:GetPolicy()
    return {
        allowed_fields = clone_table(ALLOWED_FIELDS),
        min_age = MIN_AGE,
        max_age = MAX_AGE,
        max_name_length = MAX_NAME_LENGTH,
        max_species_length = MAX_SPECIES_LENGTH,
        max_biography_length = MAX_BIOGRAPHY_LENGTH,
    }
end

function CharacterCreationService:ValidateCharacterPayload(character_payload)
    if type(character_payload) ~= "table" then
        return false, {
            code = "character-payload-required",
            details = {
                "payload-must-be-table",
            },
        }
    end

    local validation_errors = {}

    for field_name, _ in pairs(character_payload) do
        if ALLOWED_FIELDS[field_name] ~= true then
            validation_errors[#validation_errors + 1] = "field-not-allowed:" .. tostring(field_name)
        end
    end

    local sanitized_payload = {}

    local first_name = trim_string(character_payload.first_name)

    if first_name == nil or first_name == "" then
        validation_errors[#validation_errors + 1] = "first-name-required"
    elseif #first_name > MAX_NAME_LENGTH then
        validation_errors[#validation_errors + 1] = "first-name-too-long"
    else
        sanitized_payload.first_name = first_name
    end

    local last_name = trim_string(character_payload.last_name)

    if last_name == nil or last_name == "" then
        validation_errors[#validation_errors + 1] = "last-name-required"
    elseif #last_name > MAX_NAME_LENGTH then
        validation_errors[#validation_errors + 1] = "last-name-too-long"
    else
        sanitized_payload.last_name = last_name
    end

    local normalized_age = normalize_age(character_payload.age)

    if normalized_age == nil then
        validation_errors[#validation_errors + 1] = "age-required"
    elseif normalized_age < MIN_AGE or normalized_age > MAX_AGE then
        validation_errors[#validation_errors + 1] = "age-out-of-range"
    else
        sanitized_payload.age = normalized_age
    end

    local species = trim_string(character_payload.species)

    if species == nil or species == "" then
        validation_errors[#validation_errors + 1] = "species-required"
    elseif #species > MAX_SPECIES_LENGTH then
        validation_errors[#validation_errors + 1] = "species-too-long"
    else
        sanitized_payload.species = species
    end

    local biography = trim_string(character_payload.biography)

    if biography == nil or biography == "" then
        sanitized_payload.biography = ""
    elseif #biography > MAX_BIOGRAPHY_LENGTH then
        validation_errors[#validation_errors + 1] = "biography-too-long"
    else
        sanitized_payload.biography = biography
    end

    if #validation_errors > 0 then
        return false, {
            code = "character-validation-failed",
            details = validation_errors,
        }
    end

    return true, sanitized_payload
end

function CharacterCreationService:CreateCharacterForPlayer(player_or_row, character_payload, callback)
    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if self.repository == nil then
        callback(false, {
            code = "character-repository-missing",
        })

        return true
    end

    local player_row_id = normalize_player_row_id(player_or_row)

    if player_row_id == nil then
        callback(false, {
            code = "player-not-loaded",
        })

        return true
    end

    local is_valid, sanitized_payload_or_error = self:ValidateCharacterPayload(character_payload)

    if not is_valid then
        callback(false, sanitized_payload_or_error)
        return true
    end

    Console.Log(
        "[gr_characters][creation-service] Creating character for player_row_id=%s with validated server payload.",
        tostring(player_row_id)
    )

    local dispatched, dispatch_error = self.repository:InsertCharacter(
        player_row_id,
        sanitized_payload_or_error,
        function(is_success, result_or_error)
            if not is_success then
                callback(false, {
                    code = "character-insert-failed",
                    cause = result_or_error,
                })

                return
            end

            callback(true, {
                player_id = player_row_id,
                rows_affected = result_or_error.rows_affected,
                sanitized_payload = clone_table(sanitized_payload_or_error),
                defaults_applied = {
                    money_cash = 0,
                    money_bank = 0,
                    position_x = 0,
                    position_y = 0,
                    position_z = 0,
                },
            })
        end
    )

    if not dispatched then
        return false, dispatch_error
    end

    return true
end

GRCharacters.Server.CharacterCreationServiceClass = CharacterCreationService

return CharacterCreationService

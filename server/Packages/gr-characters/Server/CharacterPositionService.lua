GRCharacters = GRCharacters or {}
GRCharacters.Server = GRCharacters.Server or {}

local CharacterPositionService = {}
CharacterPositionService.__index = CharacterPositionService

local AUTO_SAVE_INTERVAL_MS = 60000
local MIN_SAVE_INTERVAL_MS = 45000
local MIN_POSITION_DELTA_UNITS = 100

local function clone_table(source)
    if type(source) ~= "table" then
        return nil
    end

    local copy = {}

    for key, value in pairs(source) do
        if type(value) == "table" then
            copy[key] = clone_table(value)
        else
            copy[key] = value
        end
    end

    return copy
end

local function normalize_platform_id(player_or_platform_id)
    if type(player_or_platform_id) == "string" then
        if player_or_platform_id == "" then
            return nil
        end

        return player_or_platform_id
    end

    if type(player_or_platform_id) ~= "table" and type(player_or_platform_id) ~= "userdata" then
        return nil
    end

    if type(player_or_platform_id.GetAccountID) == "function" then
        return player_or_platform_id:GetAccountID()
    end

    if type(player_or_platform_id.platform_id) == "string" and player_or_platform_id.platform_id ~= "" then
        return player_or_platform_id.platform_id
    end

    return nil
end

local function normalize_character_id(character_id)
    if type(character_id) == "number" then
        if character_id < 1 or character_id % 1 ~= 0 then
            return nil
        end

        return math.floor(character_id)
    end

    if type(character_id) == "string" then
        if character_id:match("^%d+$") == nil then
            return nil
        end

        local parsed_id = tonumber(character_id)

        if parsed_id == nil or parsed_id < 1 then
            return nil
        end

        return math.floor(parsed_id)
    end

    return nil
end

local function read_coordinate(value, lower_key, upper_key)
    if type(value) ~= "table" and type(value) ~= "userdata" then
        return nil
    end

    local coordinate = value[lower_key]

    if type(coordinate) ~= "number" then
        coordinate = value[upper_key]
    end

    if type(coordinate) ~= "number" then
        return nil
    end

    return coordinate
end

local function normalize_position(position)
    local x = read_coordinate(position, "x", "X")
    local y = read_coordinate(position, "y", "Y")
    local z = read_coordinate(position, "z", "Z")

    if x == nil or y == nil or z == nil then
        return nil
    end

    return {
        x = x,
        y = y,
        z = z,
    }
end

local function normalize_rotation(rotation)
    if type(rotation) ~= "table" and type(rotation) ~= "userdata" then
        return nil
    end

    return rotation
end

local function is_position_uninitialized(position)
    return position.x == 0 and position.y == 0 and position.z == 0
end

local function calculate_distance_squared(position_a, position_b)
    local delta_x = position_a.x - position_b.x
    local delta_y = position_a.y - position_b.y
    local delta_z = position_a.z - position_b.z

    return (delta_x * delta_x) + (delta_y * delta_y) + (delta_z * delta_z)
end

function CharacterPositionService.Create(repository, player_service, selection_service)
    local self = setmetatable({}, CharacterPositionService)

    self.repository = repository
    self.player_service = player_service
    self.selection_service = selection_service
    self.last_saved_position_by_platform_id = {}
    self.last_saved_at_by_platform_id = {}
    self.save_in_flight_by_platform_id = {}
    self.auto_save_timer_id = nil

    return self
end

function CharacterPositionService:GetPolicy()
    return {
        auto_save_interval_ms = AUTO_SAVE_INTERVAL_MS,
        min_save_interval_ms = MIN_SAVE_INTERVAL_MS,
        min_position_delta_units = MIN_POSITION_DELTA_UNITS,
        zero_vector_is_uninitialized = true,
        fallback_order = {
            "persisted-character-position",
            "map-spawn-point",
        },
    }
end

function CharacterPositionService:UpdateCachedPosition(platform_id, position, timestamp_ms)
    self.last_saved_position_by_platform_id[platform_id] = clone_table(position)
    self.last_saved_at_by_platform_id[platform_id] = timestamp_ms

    if self.selection_service ~= nil and type(self.selection_service.UpdateActiveCharacterPosition) == "function" then
        self.selection_service:UpdateActiveCharacterPosition(platform_id, position)
    end
end

function CharacterPositionService:ForgetPlayerPositionState(player_or_platform_id)
    local platform_id = normalize_platform_id(player_or_platform_id)

    if platform_id == nil then
        return false, "platform-id-required"
    end

    self.last_saved_position_by_platform_id[platform_id] = nil
    self.last_saved_at_by_platform_id[platform_id] = nil
    self.save_in_flight_by_platform_id[platform_id] = nil

    return true
end

function CharacterPositionService:ResolveSpawnDataForCharacterRow(character_row)
    if type(character_row) ~= "table" then
        return false, {
            code = "character-row-required",
        }
    end

    local persisted_position = normalize_position({
        x = character_row.position_x,
        y = character_row.position_y,
        z = character_row.position_z,
    })

    if persisted_position ~= nil and not is_position_uninitialized(persisted_position) then
        return true, {
            source = "persisted-character-position",
            location = persisted_position,
            rotation = nil,
        }
    end

    if type(Server) ~= "table" or type(Server.GetMapSpawnPoints) ~= "function" then
        return false, {
            code = "map-spawn-points-unavailable",
        }
    end

    local spawn_points = Server.GetMapSpawnPoints()

    if type(spawn_points) ~= "table" then
        return false, {
            code = "map-spawn-points-unavailable",
        }
    end

    for _, spawn_point in ipairs(spawn_points) do
        local spawn_location = normalize_position(spawn_point.location)

        if spawn_location ~= nil then
            return true, {
                source = "map-spawn-point",
                location = spawn_location,
                rotation = normalize_rotation(spawn_point.rotation),
            }
        end
    end

    return false, {
        code = "map-spawn-point-required",
    }
end

function CharacterPositionService:ResolveSpawnDataForActiveCharacter(player_or_platform_id)
    if self.selection_service == nil then
        return false, {
            code = "selection-service-missing",
        }
    end

    local active_character_row = self.selection_service:GetActiveCharacterRow(player_or_platform_id)

    if active_character_row == nil then
        return false, {
            code = "active-character-required",
        }
    end

    return self:ResolveSpawnDataForCharacterRow(active_character_row)
end

function CharacterPositionService:CollectControlledCharacterPosition(player)
    if type(player) ~= "table" and type(player) ~= "userdata" then
        return false, {
            code = "player-required",
        }
    end

    if type(player.GetControlledCharacter) ~= "function" then
        return false, {
            code = "player-controlled-character-unavailable",
        }
    end

    local controlled_character = player:GetControlledCharacter()

    if controlled_character == nil then
        return false, {
            code = "controlled-character-required",
        }
    end

    if type(controlled_character.IsValid) == "function" and not controlled_character:IsValid() then
        return false, {
            code = "controlled-character-invalid",
        }
    end

    if type(controlled_character.GetLocation) ~= "function" then
        return false, {
            code = "character-location-unavailable",
        }
    end

    local normalized_position = normalize_position(controlled_character:GetLocation())

    if normalized_position == nil then
        return false, {
            code = "position-invalid",
        }
    end

    return true, {
        controlled_character = controlled_character,
        position = normalized_position,
    }
end

function CharacterPositionService:SaveActiveCharacterPosition(player, callback, options)
    options = options or {}

    if self.repository == nil then
        if type(callback) == "function" then
            callback(false, {
                code = "character-repository-missing",
            })
        end

        return true
    end

    if self.player_service == nil then
        if type(callback) == "function" then
            callback(false, {
                code = "player-service-missing",
            })
        end

        return true
    end

    if self.selection_service == nil then
        if type(callback) == "function" then
            callback(false, {
                code = "selection-service-missing",
            })
        end

        return true
    end

    local platform_id = normalize_platform_id(player)

    if platform_id == nil then
        if type(callback) == "function" then
            callback(false, {
                code = "platform-id-required",
            })
        end

        return true
    end

    local player_row = self.player_service:GetLoadedPlayerRow(platform_id)

    if player_row == nil then
        if type(callback) == "function" then
            callback(false, {
                code = "player-not-loaded",
                platform_id = platform_id,
            })
        end

        return true
    end

    local active_character_id = normalize_character_id(self.selection_service:GetActiveCharacterId(platform_id))
    local active_character_row = self.selection_service:GetActiveCharacterRow(platform_id)

    if active_character_id == nil then
        if type(callback) == "function" then
            callback(false, {
                code = "active-character-required",
                platform_id = platform_id,
                player_id = player_row.id,
            })
        end

        return true
    end

    local active_row_character_id = normalize_character_id(active_character_row and active_character_row.id or nil)

    if active_row_character_id == nil or active_row_character_id ~= active_character_id then
        if type(callback) == "function" then
            callback(false, {
                code = "active-character-invalid",
                platform_id = platform_id,
                player_id = player_row.id,
                active_character_id = active_character_id,
            })
        end

        return true
    end

    local expected_character_id = normalize_character_id(options.expected_character_id)

    if options.expected_character_id ~= nil and expected_character_id == nil then
        if type(callback) == "function" then
            callback(false, {
                code = "character-id-required",
                platform_id = platform_id,
                player_id = player_row.id,
            })
        end

        return true
    end

    if expected_character_id ~= nil and expected_character_id ~= active_character_id then
        if type(callback) == "function" then
            callback(false, {
                code = "character-id-mismatch",
                platform_id = platform_id,
                player_id = player_row.id,
                active_character_id = active_character_id,
                requested_character_id = expected_character_id,
            })
        end

        return true
    end

    if self.save_in_flight_by_platform_id[platform_id] then
        if type(callback) == "function" then
            callback(false, {
                code = "position-save-in-flight",
                platform_id = platform_id,
                player_id = player_row.id,
                character_id = active_character_id,
            })
        end

        return true
    end

    local is_position_ready, position_payload_or_error = self:CollectControlledCharacterPosition(player)

    if not is_position_ready then
        position_payload_or_error.platform_id = platform_id
        position_payload_or_error.player_id = player_row.id
        position_payload_or_error.character_id = active_character_id

        if type(callback) == "function" then
            callback(false, position_payload_or_error)
        end

        return true
    end

    local current_timestamp_ms = nil

    if type(Server) == "table" and type(Server.GetTime) == "function" then
        current_timestamp_ms = Server.GetTime()
    end

    local last_saved_at_ms = self.last_saved_at_by_platform_id[platform_id]

    if not options.force and type(current_timestamp_ms) == "number" and type(last_saved_at_ms) == "number" then
        local elapsed_ms = current_timestamp_ms - last_saved_at_ms

        if elapsed_ms < MIN_SAVE_INTERVAL_MS then
            if type(callback) == "function" then
                callback(false, {
                    code = "position-save-throttled",
                    platform_id = platform_id,
                    player_id = player_row.id,
                    character_id = active_character_id,
                    elapsed_ms = elapsed_ms,
                    min_interval_ms = MIN_SAVE_INTERVAL_MS,
                })
            end

            return true
        end
    end

    local last_saved_position = self.last_saved_position_by_platform_id[platform_id]

    if not options.force and last_saved_position ~= nil then
        local moved_distance_squared = calculate_distance_squared(
            position_payload_or_error.position,
            last_saved_position
        )

        if moved_distance_squared < (MIN_POSITION_DELTA_UNITS * MIN_POSITION_DELTA_UNITS) then
            if type(callback) == "function" then
                callback(false, {
                    code = "position-save-not-needed",
                    platform_id = platform_id,
                    player_id = player_row.id,
                    character_id = active_character_id,
                    min_position_delta_units = MIN_POSITION_DELTA_UNITS,
                })
            end

            return true
        end
    end

    self.save_in_flight_by_platform_id[platform_id] = true

    Console.Log(
        "[gr_characters][position-service] Saving active character position for platform_id=%s player_id=%s character_id=%s reason=%s.",
        tostring(platform_id),
        tostring(player_row.id),
        tostring(active_character_id),
        tostring(options.reason or "unspecified")
    )

    local dispatched, dispatch_error = self.repository:UpdateCharacterPosition(
        active_character_id,
        position_payload_or_error.position,
        function(is_success, result_or_error)
            self.save_in_flight_by_platform_id[platform_id] = nil

            if not is_success then
                if type(callback) == "function" then
                    callback(false, {
                        code = "character-position-save-failed",
                        cause = result_or_error,
                        platform_id = platform_id,
                        player_id = player_row.id,
                        character_id = active_character_id,
                    })
                end

                return
            end

            self:UpdateCachedPosition(
                platform_id,
                position_payload_or_error.position,
                type(current_timestamp_ms) == "number" and current_timestamp_ms or nil
            )

            if type(callback) == "function" then
                callback(true, {
                    code = "position-saved",
                    platform_id = platform_id,
                    player_id = player_row.id,
                    character_id = active_character_id,
                    position = clone_table(position_payload_or_error.position),
                    rows_affected = result_or_error.rows_affected,
                })
            end
        end
    )

    if not dispatched then
        self.save_in_flight_by_platform_id[platform_id] = nil
        return false, dispatch_error
    end

    return true
end

function CharacterPositionService:SaveAllActiveCharacterPositions()
    for _, player in pairs(Player.GetAll()) do
        self:SaveActiveCharacterPosition(player, nil, {
            reason = "periodic-auto-save",
        })
    end
end

function CharacterPositionService:StartAutoSave()
    if self.auto_save_timer_id ~= nil and Timer.IsValid(self.auto_save_timer_id) then
        return true
    end

    self.auto_save_timer_id = Timer.SetInterval(function()
        self:SaveAllActiveCharacterPositions()
    end, AUTO_SAVE_INTERVAL_MS)

    Console.Log(
        "[gr_characters][position-service] Active character position auto-save enabled with interval=%sms.",
        tostring(AUTO_SAVE_INTERVAL_MS)
    )

    return true
end

function CharacterPositionService:StopAutoSave()
    if self.auto_save_timer_id ~= nil and Timer.IsValid(self.auto_save_timer_id) then
        Timer.ClearInterval(self.auto_save_timer_id)
    end

    self.auto_save_timer_id = nil
end

GRCharacters.Server.CharacterPositionServiceClass = CharacterPositionService

return CharacterPositionService

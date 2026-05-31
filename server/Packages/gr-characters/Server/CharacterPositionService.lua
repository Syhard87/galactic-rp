GRCharacters = GRCharacters or {}
GRCharacters.Server = GRCharacters.Server or {}

local CharacterPositionService = {}
CharacterPositionService.__index = CharacterPositionService

local AUTO_SAVE_INTERVAL_MS = 60000
local MIN_SAVE_INTERVAL_MS = 45000
local MIN_POSITION_DELTA_UNITS = 100
local FALLBACK_SPAWN_LOCATION = {
    x = 0,
    y = 0,
    z = 150,
}

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

    if type(coordinate) ~= "number" and type(coordinate) ~= "string" then
        coordinate = value[upper_key]
    end

    if type(coordinate) == "string" then
        coordinate = tonumber(coordinate)
    end

    if type(coordinate) ~= "number" then
        return nil
    end

    if coordinate ~= coordinate or coordinate == math.huge or coordinate == -math.huge then
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

local function build_default_rotation()
    if Rotator ~= nil then
        local is_created, rotation = pcall(Rotator, 0, 0, 0)

        if is_created then
            return rotation
        end
    end

    return {
        pitch = 0,
        yaw = 0,
        roll = 0,
    }
end

local function build_vector(position)
    if Vector ~= nil then
        local is_created, vector = pcall(Vector, position.x, position.y, position.z)

        if is_created then
            return vector
        end
    end

    return clone_table(position)
end

local function build_rotation_for_spawn(rotation)
    if rotation ~= nil and type(rotation) == "userdata" then
        return true, rotation
    end

    if Rotator == nil then
        return false, "rotator-constructor-unavailable"
    end

    local pitch = 0
    local yaw = 0
    local roll = 0

    if type(rotation) == "table" then
        pitch = read_coordinate(rotation, "pitch", "Pitch") or 0
        yaw = read_coordinate(rotation, "yaw", "Yaw") or 0
        roll = read_coordinate(rotation, "roll", "Roll") or 0
    end

    local is_created, spawn_rotation = pcall(Rotator, pitch, yaw, roll)

    if not is_created then
        return false, "rotator-constructor-failed"
    end

    return true, spawn_rotation
end

local function build_vector_for_spawn(position)
    if Vector == nil then
        return false, "vector-constructor-unavailable"
    end

    local is_created, vector = pcall(Vector, position.x, position.y, position.z)

    if not is_created then
        return false, "vector-constructor-failed"
    end

    return true, vector
end

local function is_position_uninitialized(position)
    return position.x == 0 and position.y == 0 and position.z == 0
end

local function resolve_faction_spawn_data(character_row)
    local faction_id = normalize_character_id(character_row and character_row.faction_id or nil)
    local spawn_point = nil
    local spawn_location = nil
    local spawn_rotation = nil

    if faction_id == nil then
        return nil
    end

    if type(GRFactionsBridge) ~= "table" or type(GRFactionsBridge.GetSpawnPointForFaction) ~= "function" then
        return nil
    end

    spawn_point = GRFactionsBridge.GetSpawnPointForFaction(faction_id)

    if type(spawn_point) ~= "table" then
        return nil
    end

    spawn_location = normalize_position(spawn_point.location or spawn_point)

    if spawn_location == nil then
        return nil
    end

    spawn_rotation = normalize_rotation(spawn_point.rotation) or build_default_rotation()

    return {
        source = "faction-spawn-point",
        faction_id = faction_id,
        location = spawn_location,
        rotation = spawn_rotation,
    }
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
        fallback_spawn_location = clone_table(FALLBACK_SPAWN_LOCATION),
        fallback_order = {
            "faction-spawn-point",
            "persisted-character-position",
            "map-spawn-point",
            "server-fallback-position",
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

    local faction_spawn_data = resolve_faction_spawn_data(character_row)

    if faction_spawn_data ~= nil then
        Console.Log(
            "[gr_characters][position-service] active character spawn faction used faction_id=%s location=%s,%s,%s.",
            tostring(faction_spawn_data.faction_id),
            tostring(faction_spawn_data.location.x),
            tostring(faction_spawn_data.location.y),
            tostring(faction_spawn_data.location.z)
        )

        return true, faction_spawn_data
    end

    local persisted_position = normalize_position({
        x = character_row.position_x,
        y = character_row.position_y,
        z = character_row.position_z,
    })

    if persisted_position ~= nil and not is_position_uninitialized(persisted_position) then
        Console.Log(
            "[gr_characters][position-service] active character spawn resolved from DB character_id=%s location=%s,%s,%s.",
            tostring(character_row.id),
            tostring(persisted_position.x),
            tostring(persisted_position.y),
            tostring(persisted_position.z)
        )

        return true, {
            source = "persisted-character-position",
            location = persisted_position,
            rotation = build_default_rotation(),
        }
    end

    if type(Server) == "table" and type(Server.GetMapSpawnPoints) == "function" then
        local spawn_points = Server.GetMapSpawnPoints()

        if type(spawn_points) == "table" then
            for _, spawn_point in ipairs(spawn_points) do
                local spawn_location = normalize_position(spawn_point.location)

                if spawn_location ~= nil then
                    Console.Log(
                        "[gr_characters][position-service] active character spawn fallback used source=map-spawn-point character_id=%s location=%s,%s,%s.",
                        tostring(character_row.id),
                        tostring(spawn_location.x),
                        tostring(spawn_location.y),
                        tostring(spawn_location.z)
                    )

                    return true, {
                        source = "map-spawn-point",
                        location = spawn_location,
                        rotation = normalize_rotation(spawn_point.rotation) or build_default_rotation(),
                    }
                end
            end
        end
    end

    Console.Log(
        "[gr_characters][position-service] active character spawn fallback used source=server-fallback-position character_id=%s location=%s,%s,%s.",
        tostring(character_row.id),
        tostring(FALLBACK_SPAWN_LOCATION.x),
        tostring(FALLBACK_SPAWN_LOCATION.y),
        tostring(FALLBACK_SPAWN_LOCATION.z)
    )

    return true, {
        source = "server-fallback-position",
        location = clone_table(FALLBACK_SPAWN_LOCATION),
        rotation = build_default_rotation(),
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
        Console.Log("[gr_characters][position-service] active character spawn refused because no active character.")

        return false, {
            code = "active-character-required",
        }
    end

    return self:ResolveSpawnDataForCharacterRow(active_character_row)
end

function CharacterPositionService:SpawnActiveCharacter(player, options)
    options = options or {}

    if type(player) ~= "table" and type(player) ~= "userdata" then
        return false, {
            code = "player-required",
        }
    end

    if type(player.GetAccountID) ~= "function" then
        return false, {
            code = "platform-id-required",
        }
    end

    if Character == nil or Vector == nil or Rotator == nil then
        return false, {
            code = "character-spawn-api-unavailable",
        }
    end

    if type(player.Possess) ~= "function" then
        return false, {
            code = "player-possess-unavailable",
        }
    end

    local platform_id = player:GetAccountID()
    local is_resolved, spawn_data_or_error = self:ResolveSpawnDataForActiveCharacter(platform_id)

    if not is_resolved then
        return false, spawn_data_or_error
    end

    local is_location_ready, location_or_error = build_vector_for_spawn(spawn_data_or_error.location)

    if not is_location_ready then
        return false, {
            code = location_or_error,
            platform_id = platform_id,
        }
    end

    local is_rotation_ready, rotation_or_error = build_rotation_for_spawn(
        spawn_data_or_error.rotation or build_default_rotation()
    )

    if not is_rotation_ready then
        return false, {
            code = rotation_or_error,
            platform_id = platform_id,
        }
    end

    local location = location_or_error
    local rotation = rotation_or_error
    local skeletal_mesh = options.skeletal_mesh or "nanos-world::SK_Male"

    local previous_character = nil

    if type(player.GetControlledCharacter) == "function" then
        previous_character = player:GetControlledCharacter()
    end

    local is_character_created, spawned_character = pcall(Character, location, rotation, skeletal_mesh)

    if not is_character_created or spawned_character == nil then
        return false, {
            code = "character-constructor-failed",
            platform_id = platform_id,
        }
    end

    local is_possess_ok = pcall(function()
        player:Possess(spawned_character)
    end)

    if not is_possess_ok then
        if type(spawned_character.Destroy) == "function" then
            spawned_character:Destroy()
        end

        return false, {
            code = "player-possess-failed",
            platform_id = platform_id,
        }
    end

    local possessed_character = nil

    if type(player.GetControlledCharacter) == "function" then
        possessed_character = player:GetControlledCharacter()
    end

    if possessed_character == nil then
        if type(spawned_character.Destroy) == "function" then
            spawned_character:Destroy()
        end

        return false, {
            code = "controlled-character-missing-after-possess",
            platform_id = platform_id,
        }
    end

    if type(possessed_character.GetLocation) ~= "function" then
        if type(spawned_character.Destroy) == "function" then
            spawned_character:Destroy()
        end

        return false, {
            code = "controlled-character-location-unavailable-after-possess",
            platform_id = platform_id,
        }
    end

    if previous_character ~= nil and previous_character ~= possessed_character and type(previous_character.Destroy) == "function" then
        previous_character:Destroy()
    end

    Console.Log(
        "[gr_characters][position-service] Active character spawned for platform_id=%s source=%s location=%s,%s,%s.",
        tostring(platform_id),
        tostring(spawn_data_or_error.source),
        tostring(spawn_data_or_error.location.x),
        tostring(spawn_data_or_error.location.y),
        tostring(spawn_data_or_error.location.z)
    )

    return true, {
        code = "active-character-spawned",
        platform_id = platform_id,
        source = spawn_data_or_error.source,
        location = clone_table(spawn_data_or_error.location),
        character = possessed_character,
    }
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

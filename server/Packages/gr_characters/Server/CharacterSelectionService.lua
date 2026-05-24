GRCharacters = GRCharacters or {}
GRCharacters.Server = GRCharacters.Server or {}

local CharacterSelectionService = {}
CharacterSelectionService.__index = CharacterSelectionService

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

local function clone_array(source)
    if type(source) ~= "table" then
        return {}
    end

    local copy = {}

    for index, value in ipairs(source) do
        if type(value) == "table" then
            copy[index] = clone_table(value)
        else
            copy[index] = value
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

local function normalize_player_row_id(player_row)
    if type(player_row) ~= "table" then
        return nil
    end

    if type(player_row.id) == "number" then
        if player_row.id < 1 then
            return nil
        end

        return math.floor(player_row.id)
    end

    if type(player_row.id) == "string" then
        local parsed_id = tonumber(player_row.id)

        if parsed_id == nil or parsed_id < 1 then
            return nil
        end

        return math.floor(parsed_id)
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

local function is_character_row_selectable(character_row)
    if type(character_row) ~= "table" then
        return false, "character-row-required"
    end

    if normalize_character_id(character_row.id) == nil then
        return false, "character-id-invalid"
    end

    if normalize_player_row_id({ id = character_row.player_id }) == nil then
        return false, "character-player-id-invalid"
    end

    if type(character_row.first_name) ~= "string" or character_row.first_name == "" then
        return false, "character-first-name-invalid"
    end

    if type(character_row.last_name) ~= "string" or character_row.last_name == "" then
        return false, "character-last-name-invalid"
    end

    return true, nil
end

local function build_character_list_state(status, platform_id, player_row_id, characters)
    return {
        status = status,
        platform_id = platform_id,
        player_id = player_row_id,
        character_count = #characters,
        characters = clone_array(characters),
    }
end

function CharacterSelectionService.Create(repository, player_service)
    local self = setmetatable({}, CharacterSelectionService)

    self.repository = repository
    self.player_service = player_service
    self.character_lists_by_platform_id = {}
    self.selection_states_by_platform_id = {}
    self.active_character_rows_by_platform_id = {}
    self.active_character_ids_by_platform_id = {}

    return self
end

function CharacterSelectionService:SetSelectionState(platform_id, state)
    if type(platform_id) ~= "string" or platform_id == "" then
        return
    end

    self.selection_states_by_platform_id[platform_id] = clone_table(state)
end

function CharacterSelectionService:GetSelectionState(player_or_platform_id)
    local platform_id = normalize_platform_id(player_or_platform_id)

    if platform_id == nil then
        return nil
    end

    return clone_table(self.selection_states_by_platform_id[platform_id])
end

function CharacterSelectionService:GetCachedCharacterList(player_or_platform_id)
    local platform_id = normalize_platform_id(player_or_platform_id)

    if platform_id == nil then
        return {}
    end

    return clone_array(self.character_lists_by_platform_id[platform_id])
end

function CharacterSelectionService:GetActiveCharacterId(player_or_platform_id)
    local platform_id = normalize_platform_id(player_or_platform_id)

    if platform_id == nil then
        return nil
    end

    return self.active_character_ids_by_platform_id[platform_id]
end

function CharacterSelectionService:GetActiveCharacterRow(player_or_platform_id)
    local platform_id = normalize_platform_id(player_or_platform_id)

    if platform_id == nil then
        return nil
    end

    return clone_table(self.active_character_rows_by_platform_id[platform_id])
end

function CharacterSelectionService:UpdateActiveCharacterPosition(player_or_platform_id, position)
    local platform_id = normalize_platform_id(player_or_platform_id)

    if platform_id == nil then
        return false, "platform-id-required"
    end

    if type(position) ~= "table" then
        return false, "position-required"
    end

    local active_character_row = self.active_character_rows_by_platform_id[platform_id]

    if type(active_character_row) ~= "table" then
        return false, "active-character-required"
    end

    active_character_row.position_x = position.x
    active_character_row.position_y = position.y
    active_character_row.position_z = position.z

    return true
end

function CharacterSelectionService:InvalidatePlayerState(player_or_platform_id)
    local platform_id = normalize_platform_id(player_or_platform_id)

    if platform_id == nil then
        return false, "platform-id-required"
    end

    self.character_lists_by_platform_id[platform_id] = nil
    self.selection_states_by_platform_id[platform_id] = nil
    self.active_character_rows_by_platform_id[platform_id] = nil
    self.active_character_ids_by_platform_id[platform_id] = nil

    return true
end

function CharacterSelectionService:LoadCharactersForPlayer(player_or_platform_id, callback)
    if self.repository == nil then
        return false, "character-repository-missing"
    end

    if self.player_service == nil then
        return false, "player-service-missing"
    end

    local platform_id = normalize_platform_id(player_or_platform_id)

    if platform_id == nil then
        if type(callback) == "function" then
            callback(false, {
                code = "platform-id-required",
            })
        end

        return true
    end

    local player_row = self.player_service:GetLoadedPlayerRow(platform_id)
    local player_row_id = normalize_player_row_id(player_row)

    if player_row_id == nil then
        local error_state = {
            code = "player-not-loaded",
            platform_id = platform_id,
        }

        self:SetSelectionState(platform_id, {
            status = "blocked",
            platform_id = platform_id,
            error = error_state.code,
        })

        if type(callback) == "function" then
            callback(false, error_state)
        end

        return true
    end

    self:SetSelectionState(platform_id, {
        status = "loading_characters",
        platform_id = platform_id,
        player_id = player_row_id,
    })

    Console.Log(
        "[gr_characters][selection-service] Loading selectable characters for platform_id=%s player_id=%s.",
        tostring(platform_id),
        tostring(player_row_id)
    )

    local dispatched, dispatch_error = self.repository:GetCharactersByPlayerId(player_row_id, function(is_success, characters, error)
        if not is_success then
            local blocked_state = {
                status = "blocked",
                platform_id = platform_id,
                player_id = player_row_id,
                error = error,
            }

            self.character_lists_by_platform_id[platform_id] = nil
            self.active_character_rows_by_platform_id[platform_id] = nil
            self.active_character_ids_by_platform_id[platform_id] = nil
            self:SetSelectionState(platform_id, blocked_state)

            if type(callback) == "function" then
                callback(false, {
                    code = "character-list-load-failed",
                    platform_id = platform_id,
                    player_id = player_row_id,
                    cause = error,
                })
            end

            return
        end

        local safe_characters = {}

        for _, character_row in ipairs(characters or {}) do
            local is_selectable, selectable_error = is_character_row_selectable(character_row)

            if is_selectable then
                safe_characters[#safe_characters + 1] = clone_table(character_row)
            else
                Console.Log(
                    "[gr_characters][selection-service] Ignoring invalid character row id=%s for player_id=%s reason=%s.",
                    tostring(character_row.id),
                    tostring(player_row_id),
                    tostring(selectable_error)
                )
            end
        end

        self.character_lists_by_platform_id[platform_id] = clone_array(safe_characters)
        self.active_character_rows_by_platform_id[platform_id] = nil
        self.active_character_ids_by_platform_id[platform_id] = nil

        if #safe_characters == 0 then
            local empty_state = build_character_list_state(
                "waiting_character_creation",
                platform_id,
                player_row_id,
                safe_characters
            )

            self:SetSelectionState(platform_id, empty_state)

            if type(callback) == "function" then
                callback(true, clone_table(empty_state))
            end

            return
        end

        local ready_state = build_character_list_state(
            "waiting_character_selection",
            platform_id,
            player_row_id,
            safe_characters
        )

        self:SetSelectionState(platform_id, ready_state)

        if type(callback) == "function" then
            callback(true, clone_table(ready_state))
        end
    end)

    if not dispatched then
        return false, dispatch_error
    end

    return true
end

function CharacterSelectionService:SelectCharacterForPlayer(player_or_platform_id, character_id, callback)
    if self.repository == nil then
        return false, "character-repository-missing"
    end

    if self.player_service == nil then
        return false, "player-service-missing"
    end

    local platform_id = normalize_platform_id(player_or_platform_id)

    if platform_id == nil then
        if type(callback) == "function" then
            callback(false, {
                code = "platform-id-required",
            })
        end

        return true
    end

    local player_row = self.player_service:GetLoadedPlayerRow(platform_id)
    local player_row_id = normalize_player_row_id(player_row)

    if player_row_id == nil then
        if type(callback) == "function" then
            callback(false, {
                code = "player-not-loaded",
                platform_id = platform_id,
            })
        end

        return true
    end

    local normalized_character_id = normalize_character_id(character_id)

    if normalized_character_id == nil then
        if type(callback) == "function" then
            callback(false, {
                code = "character-id-required",
                platform_id = platform_id,
                player_id = player_row_id,
            })
        end

        return true
    end

    self:SetSelectionState(platform_id, {
        status = "selecting_character",
        platform_id = platform_id,
        player_id = player_row_id,
        requested_character_id = normalized_character_id,
    })

    Console.Log(
        "[gr_characters][selection-service] Validating character selection for platform_id=%s player_id=%s character_id=%s.",
        tostring(platform_id),
        tostring(player_row_id),
        tostring(normalized_character_id)
    )

    local cached_characters = self.character_lists_by_platform_id[platform_id] or {}
    local was_character_listed = false

    for _, character_row in ipairs(cached_characters) do
        if normalize_character_id(character_row.id) == normalized_character_id then
            was_character_listed = true
            break
        end
    end

    local dispatched, dispatch_error = self.repository:FindCharacterById(normalized_character_id, function(is_success, character_row, error)
        if not is_success then
            local blocked_state = {
                status = "blocked",
                platform_id = platform_id,
                player_id = player_row_id,
                requested_character_id = normalized_character_id,
                error = error,
            }

            self.active_character_rows_by_platform_id[platform_id] = nil
            self.active_character_ids_by_platform_id[platform_id] = nil
            self:SetSelectionState(platform_id, blocked_state)

            if type(callback) == "function" then
                callback(false, {
                    code = "character-lookup-failed",
                    platform_id = platform_id,
                    player_id = player_row_id,
                    character_id = normalized_character_id,
                    cause = error,
                })
            end

            return
        end

        if character_row == nil then
            self.active_character_rows_by_platform_id[platform_id] = nil
            self.active_character_ids_by_platform_id[platform_id] = nil

            local missing_code = "character-not-found"

            if was_character_listed then
                missing_code = "character-unavailable"
            end

            self:SetSelectionState(platform_id, {
                status = "waiting_character_selection",
                platform_id = platform_id,
                player_id = player_row_id,
                requested_character_id = normalized_character_id,
                error = missing_code,
                character_count = #cached_characters,
            })

            if type(callback) == "function" then
                callback(false, {
                    code = missing_code,
                    platform_id = platform_id,
                    player_id = player_row_id,
                    character_id = normalized_character_id,
                })
            end

            return
        end

        local normalized_owner_id = normalize_player_row_id({ id = character_row.player_id })

        if normalized_owner_id ~= player_row_id then
            self.active_character_rows_by_platform_id[platform_id] = nil
            self.active_character_ids_by_platform_id[platform_id] = nil
            self:SetSelectionState(platform_id, {
                status = "waiting_character_selection",
                platform_id = platform_id,
                player_id = player_row_id,
                requested_character_id = normalized_character_id,
                error = "character-not-owned",
                character_count = #cached_characters,
            })

            if type(callback) == "function" then
                callback(false, {
                    code = "character-not-owned",
                    platform_id = platform_id,
                    player_id = player_row_id,
                    character_id = normalized_character_id,
                })
            end

            return
        end

        local is_selectable, selectable_error = is_character_row_selectable(character_row)

        if not is_selectable then
            self.active_character_rows_by_platform_id[platform_id] = nil
            self.active_character_ids_by_platform_id[platform_id] = nil
            self:SetSelectionState(platform_id, {
                status = "waiting_character_selection",
                platform_id = platform_id,
                player_id = player_row_id,
                requested_character_id = normalized_character_id,
                error = "character-invalid",
                cause = selectable_error,
                character_count = #cached_characters,
            })

            if type(callback) == "function" then
                callback(false, {
                    code = "character-invalid",
                    cause = selectable_error,
                    platform_id = platform_id,
                    player_id = player_row_id,
                    character_id = normalized_character_id,
                })
            end

            return
        end

        self.active_character_rows_by_platform_id[platform_id] = clone_table(character_row)
        self.active_character_ids_by_platform_id[platform_id] = normalized_character_id

        local selected_state = {
            status = "character-selected",
            platform_id = platform_id,
            player_id = player_row_id,
            active_character_id = normalized_character_id,
            activation = "pending-spawn",
        }

        self:SetSelectionState(platform_id, selected_state)

        if type(callback) == "function" then
            callback(true, {
                status = "character-selected",
                platform_id = platform_id,
                player_id = player_row_id,
                active_character_id = normalized_character_id,
                character = clone_table(character_row),
                activation = "pending-spawn",
            })
        end
    end)

    if not dispatched then
        return false, dispatch_error
    end

    return true
end

GRCharacters.Server.CharacterSelectionServiceClass = CharacterSelectionService

return CharacterSelectionService

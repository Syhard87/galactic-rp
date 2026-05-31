GRCharacters = GRCharacters or {}
GRCharacters.Server = GRCharacters.Server or {}

local CharacterDevTool = {}
CharacterDevTool.__index = CharacterDevTool

local DEFAULT_PLATFORM_ID = "local-dev-platform-id"
local DEFAULT_USERNAME = "LocalDevPlayer"
local TEST_CHARACTER_PAYLOAD = {
    first_name = "Test",
    last_name = "Character",
    age = 25,
    species = "Human",
    biography = "Local development test character",
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

local function normalize_boolean(value, fallback)
    if type(value) == "boolean" then
        return value
    end

    local string_value = trim_string(value)

    if string_value == nil then
        return fallback
    end

    local lowered_value = string.lower(string_value)

    if lowered_value == "true" or lowered_value == "1" or lowered_value == "yes" or lowered_value == "on" then
        return true
    end

    if lowered_value == "false" or lowered_value == "0" or lowered_value == "no" or lowered_value == "off" then
        return false
    end

    return fallback
end

local function read_custom_settings()
    if type(Server) ~= "table" or type(Server.GetCustomSettings) ~= "function" then
        return {}
    end

    local custom_settings = Server.GetCustomSettings()

    if type(custom_settings) ~= "table" then
        return {}
    end

    return custom_settings
end

local function resolve_character_count(selection_state)
    if type(selection_state) ~= "table" then
        return 0
    end

    if type(selection_state.character_count) == "number" then
        return selection_state.character_count
    end

    if type(selection_state.characters) == "table" then
        return #selection_state.characters
    end

    return 0
end

local function resolve_first_character(selection_state)
    if type(selection_state) ~= "table" or type(selection_state.characters) ~= "table" then
        return nil
    end

    return selection_state.characters[1]
end

function CharacterDevTool.Create(character_service, player_service)
    local self = setmetatable({}, CharacterDevTool)

    self.character_service = character_service
    self.player_service = player_service
    self.custom_settings = read_custom_settings()

    return self
end

function CharacterDevTool:IsEnabled()
    return normalize_boolean(self.custom_settings.gr_characters_dev_tools_enabled, false)
end

function CharacterDevTool:GetPlatformId()
    return trim_string(self.custom_settings.gr_characters_dev_platform_id) or DEFAULT_PLATFORM_ID
end

function CharacterDevTool:GetObservedUsername()
    return trim_string(self.custom_settings.gr_characters_dev_username) or DEFAULT_USERNAME
end

function CharacterDevTool:LogSelectionOutcome(platform_id, selection_result)
    local selected_character_id = nil
    local active_character_row = self.character_service:GetActiveCharacterRow(platform_id)

    if type(selection_result) == "table" then
        selected_character_id = selection_result.active_character_id
    end

    Console.Log(
        "[gr_characters][server][dev] Active character selected id=%s.",
        tostring(selected_character_id)
    )

    if active_character_row ~= nil then
        Console.Log("[gr_characters][server][dev] Active character stored in memory.")
    end
end

function CharacterDevTool:SelectFirstCharacter(platform_id, selection_state)
    local first_character = resolve_first_character(selection_state)

    if type(first_character) ~= "table" or first_character.id == nil then
        Console.Log(
            "[gr_characters][server][dev] No selectable character is available for platform_id=%s after loading.",
            tostring(platform_id)
        )

        return
    end

    local is_started, error = self.character_service:SelectActiveCharacter(platform_id, first_character.id, function(is_success, result)
        if not is_success then
            Console.Log(
                "[gr_characters][server][dev] Character selection failed for platform_id=%s with code=%s.",
                tostring(platform_id),
                tostring(result and result.code or "selection-failed")
            )

            return
        end

        self:LogSelectionOutcome(platform_id, result)
    end)

    if not is_started then
        Console.Log(
            "[gr_characters][server][dev] Character selection dispatch failed for platform_id=%s with error=%s.",
            tostring(platform_id),
            tostring(error)
        )
    end
end

function CharacterDevTool:ReloadCharactersAfterCreate(platform_id)
    local is_started, error = self.character_service:GetCharactersForPlayer(platform_id, function(is_success, selection_state)
        if not is_success then
            Console.Log(
                "[gr_characters][server][dev] Character reload after create failed for platform_id=%s with code=%s.",
                tostring(platform_id),
                tostring(selection_state and selection_state.code or "character-reload-failed")
            )

            return
        end

        local characters_found_count = resolve_character_count(selection_state)
        local first_character = resolve_first_character(selection_state)

        if first_character ~= nil and first_character.id ~= nil then
            Console.Log(
                "[gr_characters][server][dev] Test character created id=%s.",
                tostring(first_character.id)
            )
        end

        Console.Log(
            "[gr_characters][server][dev] Characters found count=%s.",
            tostring(characters_found_count)
        )

        self:SelectFirstCharacter(platform_id, selection_state)
    end)

    if not is_started then
        Console.Log(
            "[gr_characters][server][dev] Character reload dispatch failed for platform_id=%s with error=%s.",
            tostring(platform_id),
            tostring(error)
        )
    end
end

function CharacterDevTool:CreateTestCharacter(platform_id)
    local create_method = self.character_service.CreateCharacterAndSelect
        or self.character_service.CreateCharacterForPlayer
        or self.character_service.CreateCharacter
    local is_started, error = create_method(self.character_service, platform_id, TEST_CHARACTER_PAYLOAD, function(is_success, result)
        if not is_success then
            Console.Log(
                "[gr_characters][server][dev] Test character creation failed for platform_id=%s with code=%s.",
                tostring(platform_id),
                tostring(result and result.code or "character-create-failed")
            )

            return
        end

        Console.Log(
            "[gr_characters][server][dev] Test character created and selected id=%s gameplay-ready=%s.",
            tostring(result and result.active_character_id or nil),
            tostring(result and result.gameplay_ready or false)
        )
    end)

    if not is_started then
        Console.Log(
            "[gr_characters][server][dev] Test character creation dispatch failed for platform_id=%s with error=%s.",
            tostring(platform_id),
            tostring(error)
        )
    end
end

function CharacterDevTool:LoadCharacters(platform_id)
    local is_started, error = self.character_service:GetCharactersForPlayer(platform_id, function(is_success, selection_state)
        if not is_success then
            Console.Log(
                "[gr_characters][server][dev] Character list load failed for platform_id=%s with code=%s.",
                tostring(platform_id),
                tostring(selection_state and selection_state.code or "character-list-load-failed")
            )

            return
        end

        local characters_found_count = resolve_character_count(selection_state)

        Console.Log(
            "[gr_characters][server][dev] Characters found count=%s.",
            tostring(characters_found_count)
        )

        if characters_found_count < 1 then
            self:CreateTestCharacter(platform_id)
            return
        end

        self:SelectFirstCharacter(platform_id, selection_state)
    end)

    if not is_started then
        Console.Log(
            "[gr_characters][server][dev] Character list load dispatch failed for platform_id=%s with error=%s.",
            tostring(platform_id),
            tostring(error)
        )
    end
end

function CharacterDevTool:LoadOrCreatePlayer(platform_id, observed_username)
    Console.Log(
        "[gr_characters][server][dev] Loading player by platform_id=%s",
        tostring(platform_id)
    )

    local is_started, error = self.player_service:LoadPlayerSessionByPlatformId(platform_id, observed_username, function(is_success, player_state)
        if not is_success then
            Console.Log(
                "[gr_characters][server][dev] Player load failed for platform_id=%s with error=%s.",
                tostring(platform_id),
                tostring(player_state and player_state.error or "player-load-failed")
            )

            return
        end

        if type(player_state) ~= "table" then
            Console.Log(
                "[gr_characters][server][dev] Player load returned an invalid state for platform_id=%s.",
                tostring(platform_id)
            )

            return
        end

        if player_state.status == "player-row-loaded" then
            Console.Log(
                "[gr_characters][server][dev] Player found id=%s",
                tostring(player_state.player_id)
            )
            self:LoadCharacters(platform_id)
            return
        end

        if player_state.status ~= "player-row-missing" then
            Console.Log(
                "[gr_characters][server][dev] Player load ended with status=%s for platform_id=%s.",
                tostring(player_state.status),
                tostring(platform_id)
            )

            return
        end

        local create_started, create_error = self.player_service:CreatePlayerRowByPlatformId(
            platform_id,
            observed_username,
            function(create_success, created_state)
                if not create_success then
                    Console.Log(
                        "[gr_characters][server][dev] Player creation failed for platform_id=%s with error=%s.",
                        tostring(platform_id),
                        tostring(created_state and created_state.error or "player-create-failed")
                    )

                    return
                end

                Console.Log(
                    "[gr_characters][server][dev] Player created id=%s",
                    tostring(created_state.player_id)
                )
                self:LoadCharacters(platform_id)
            end
        )

        if not create_started then
            Console.Log(
                "[gr_characters][server][dev] Player creation dispatch failed for platform_id=%s with error=%s.",
                tostring(platform_id),
                tostring(create_error)
            )
        end
    end)

    if not is_started then
        Console.Log(
            "[gr_characters][server][dev] Player load dispatch failed for platform_id=%s with error=%s.",
            tostring(platform_id),
            tostring(error)
        )
    end
end

function CharacterDevTool:Run()
    if not self:LogStatus() then
        return false
    end

    if self.character_service == nil or self.player_service == nil then
        Console.Log("[gr_characters][server][dev] Character dev tool enabled but required server services are unavailable.")
        return false
    end

    local platform_id = self:GetPlatformId()
    local observed_username = self:GetObservedUsername()

    self:LoadOrCreatePlayer(platform_id, observed_username)

    return true
end

function CharacterDevTool:LogStatus()
    if not self:IsEnabled() then
        Console.Log("[gr_characters][server][dev] Character dev tool disabled.")
        return false
    end

    Console.Log("[gr_characters][server][dev] Character dev tool enabled.")
    return true
end

GRCharacters.Server.CharacterDevToolClass = CharacterDevTool

return CharacterDevTool

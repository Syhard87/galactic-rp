GRCharacters = GRCharacters or {}
GRCharacters.Server = GRCharacters.Server or {}

local CharacterRuntimeSelfTest = {}
CharacterRuntimeSelfTest.__index = CharacterRuntimeSelfTest

local DEFAULT_PLATFORM_ID = "dev-player-001"
local DEFAULT_USERNAME = "dev_test_operator"

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

function CharacterRuntimeSelfTest.Create(database_service, character_service, player_service)
    local self = setmetatable({}, CharacterRuntimeSelfTest)

    self.database_service = database_service
    self.character_service = character_service
    self.player_service = player_service
    self.custom_settings = read_custom_settings()

    return self
end

function CharacterRuntimeSelfTest:IsEnabled()
    return normalize_boolean(self.custom_settings.gr_characters_runtime_self_test_enabled, false)
end

function CharacterRuntimeSelfTest:GetPlatformId()
    return trim_string(self.custom_settings.gr_characters_dev_platform_id) or DEFAULT_PLATFORM_ID
end

function CharacterRuntimeSelfTest:GetObservedUsername()
    return trim_string(self.custom_settings.gr_characters_dev_username) or DEFAULT_USERNAME
end

function CharacterRuntimeSelfTest:EnsureDatabaseReady()
    if self.database_service == nil then
        Console.Log("[gr_characters][server][self-test] Database service unavailable. Runtime character self-test skipped.")
        return false
    end

    if type(self.database_service.Connect) ~= "function" then
        Console.Log("[gr_characters][server][self-test] Database service has no Connect method. Runtime character self-test skipped.")
        return false
    end

    local is_connected, database_or_error = self.database_service:Connect()

    if not is_connected then
        Console.Log(
            "[gr_characters][server][self-test] Database connection unavailable with error=%s. Runtime character self-test skipped.",
            tostring(database_or_error)
        )
        return false
    end

    return true
end

function CharacterRuntimeSelfTest:LogSelectionOutcome(platform_id, selection_result)
    Console.Log(
        "[gr_characters][server][self-test] Active character selected id=%s.",
        tostring(selection_result and selection_result.active_character_id or nil)
    )

    if self.character_service:GetActiveCharacterRow(platform_id) ~= nil then
        Console.Log("[gr_characters][server][self-test] Active character stored in memory.")
    end
end

function CharacterRuntimeSelfTest:SelectFirstCharacter(platform_id, selection_state)
    local first_character = resolve_first_character(selection_state)

    if type(first_character) ~= "table" or first_character.id == nil then
        Console.Log("[gr_characters][server][self-test] No active character selected. Character creation UI will be required later.")
        return
    end

    local is_started, error = self.character_service:SelectActiveCharacter(platform_id, first_character.id, function(is_success, result)
        if not is_success then
            Console.Log(
                "[gr_characters][server][self-test] Active character selection failed for platform_id=%s with code=%s.",
                tostring(platform_id),
                tostring(result and result.code or "selection-failed")
            )
            return
        end

        self:LogSelectionOutcome(platform_id, result)
    end)

    if not is_started then
        Console.Log(
            "[gr_characters][server][self-test] Active character selection dispatch failed for platform_id=%s with error=%s.",
            tostring(platform_id),
            tostring(error)
        )
    end
end

function CharacterRuntimeSelfTest:LoadCharacters(platform_id)
    local is_started, error = self.character_service:GetCharactersForPlayer(platform_id, function(is_success, selection_state)
        if not is_success then
            Console.Log(
                "[gr_characters][server][self-test] Character list load failed for platform_id=%s with code=%s.",
                tostring(platform_id),
                tostring(selection_state and selection_state.code or "character-list-load-failed")
            )
            return
        end

        local characters_found_count = resolve_character_count(selection_state)

        Console.Log(
            "[gr_characters][server][self-test] Characters found count=%s",
            tostring(characters_found_count)
        )

        if characters_found_count < 1 then
            Console.Log("[gr_characters][server][self-test] No active character selected. Character creation UI will be required later.")
            return
        end

        self:SelectFirstCharacter(platform_id, selection_state)
    end)

    if not is_started then
        Console.Log(
            "[gr_characters][server][self-test] Character list dispatch failed for platform_id=%s with error=%s.",
            tostring(platform_id),
            tostring(error)
        )
    end
end

function CharacterRuntimeSelfTest:CreatePlayerAndContinue(platform_id, observed_username)
    local is_started, error = self.player_service:CreatePlayerRowByPlatformId(platform_id, observed_username, function(is_success, created_state)
        if not is_success then
            Console.Log(
                "[gr_characters][server][self-test] Player DB creation failed for platform_id=%s with error=%s.",
                tostring(platform_id),
                tostring(created_state and created_state.error or "player-create-failed")
            )
            return
        end

        Console.Log(
            "[gr_characters][server][self-test] Player DB loaded id=%s.",
            tostring(created_state and created_state.player_id or nil)
        )

        self:LoadCharacters(platform_id)
    end)

    if not is_started then
        Console.Log(
            "[gr_characters][server][self-test] Player DB creation dispatch failed for platform_id=%s with error=%s.",
            tostring(platform_id),
            tostring(error)
        )
    end
end

function CharacterRuntimeSelfTest:LoadOrCreatePlayer(platform_id, observed_username)
    Console.Log(
        "[gr_characters][server][self-test] Loading player by platform_id=%s",
        tostring(platform_id)
    )

    local is_started, error = self.player_service:LoadPlayerSessionByPlatformId(platform_id, observed_username, function(is_success, player_state)
        if not is_success then
            Console.Log(
                "[gr_characters][server][self-test] Player DB load failed for platform_id=%s with error=%s.",
                tostring(platform_id),
                tostring(player_state and player_state.error or "player-load-failed")
            )
            return
        end

        if type(player_state) ~= "table" then
            Console.Log(
                "[gr_characters][server][self-test] Player DB load returned an invalid state for platform_id=%s.",
                tostring(platform_id)
            )
            return
        end

        if player_state.status == "player-row-loaded" then
            Console.Log(
                "[gr_characters][server][self-test] Player DB loaded id=%s.",
                tostring(player_state.player_id)
            )
            self:LoadCharacters(platform_id)
            return
        end

        if player_state.status == "player-row-missing" then
            self:CreatePlayerAndContinue(platform_id, observed_username)
            return
        end

        Console.Log(
            "[gr_characters][server][self-test] Player DB load ended with status=%s for platform_id=%s.",
            tostring(player_state.status),
            tostring(platform_id)
        )
    end)

    if not is_started then
        Console.Log(
            "[gr_characters][server][self-test] Player DB load dispatch failed for platform_id=%s with error=%s.",
            tostring(platform_id),
            tostring(error)
        )
    end
end

function CharacterRuntimeSelfTest:Run()
    if not self:IsEnabled() then
        Console.Log("[gr_characters][server][self-test] Runtime character self-test disabled.")
        return false
    end

    Console.Log("[gr_characters][server][self-test] Runtime character self-test enabled.")

    if self.character_service == nil or self.player_service == nil then
        Console.Log("[gr_characters][server][self-test] Required character services unavailable. Runtime character self-test skipped.")
        return false
    end

    if not self:EnsureDatabaseReady() then
        return false
    end

    self:LoadOrCreatePlayer(self:GetPlatformId(), self:GetObservedUsername())

    return true
end

GRCharacters.Server.CharacterRuntimeSelfTestClass = CharacterRuntimeSelfTest

return CharacterRuntimeSelfTest

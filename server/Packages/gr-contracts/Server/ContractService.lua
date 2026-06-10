GRContracts = GRContracts or {}
GRContracts.Server = GRContracts.Server or {}

local ContractService = {}
ContractService.__index = ContractService

local MAX_REWARD_MONEY = 1000000
local MAX_DELIVERY_QUANTITY = 1000
local DEFAULT_DELIVERY_LOCATION_RADIUS = 500
local MAX_DELIVERY_LOCATION_RADIUS = 5000
local MAX_CONTRACT_LOCATION_RADIUS = 100000
local MAX_ACTIVE_JOB_CONTRACTS = 3
local DEFAULT_JOB_HISTORY_LIMIT = 5
local MAX_JOB_HISTORY_LIMIT = 20

local ALLOWED_CONTRACT_TYPES = {
    crafting = true,
    delivery = true,
    information = true,
    medical = true,
    protection = true,
    repair = true,
}

local CONTRACT_TYPE_TITLES = {
    crafting = "Crafting",
    delivery = "Delivery",
    information = "Information",
    medical = "Medical",
    protection = "Protection",
    repair = "Repair",
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

local function normalize_reward_money(value)
    if type(value) == "number" then
        if value < 0 or value > MAX_REWARD_MONEY or value % 1 ~= 0 then
            return nil
        end

        return math.floor(value)
    end

    if type(value) == "string" and value:match("^%d+$") ~= nil then
        local parsed_value = tonumber(value)

        if parsed_value ~= nil and parsed_value >= 0 and parsed_value <= MAX_REWARD_MONEY then
            return math.floor(parsed_value)
        end
    end

    return nil
end

local function normalize_non_negative_integer(value)
    if type(value) == "number" then
        if value < 0 or value % 1 ~= 0 then
            return nil
        end

        return math.floor(value)
    end

    if type(value) == "string" and value:match("^%d+$") ~= nil then
        local parsed_value = tonumber(value)

        if parsed_value ~= nil and parsed_value >= 0 then
            return math.floor(parsed_value)
        end
    end

    return nil
end

local function normalize_integer(value)
    if type(value) == "number" then
        if value % 1 ~= 0 then
            return nil
        end

        return math.floor(value)
    end

    if type(value) == "string" and value:match("^[+-]?%d+$") ~= nil then
        local parsed_value = tonumber(value)

        if parsed_value ~= nil then
            return math.floor(parsed_value)
        end
    end

    return nil
end

local function normalize_contract_id(value)
    return normalize_positive_integer(value)
end

local function normalize_contract_type(contract_type)
    local normalized_contract_type = trim_string(contract_type)

    if normalized_contract_type == nil then
        return nil
    end

    normalized_contract_type = string.lower(normalized_contract_type)

    if ALLOWED_CONTRACT_TYPES[normalized_contract_type] ~= true then
        return nil
    end

    return normalized_contract_type
end

local function normalize_description(description)
    local normalized_description = trim_string(description)

    if normalized_description == nil then
        return nil
    end

    if #normalized_description > 500 then
        return nil
    end

    return normalized_description
end

local function normalize_payment_status(payment_status)
    local normalized_payment_status = trim_string(payment_status)

    if normalized_payment_status == nil then
        return "pending"
    end

    normalized_payment_status = string.lower(normalized_payment_status)

    if normalized_payment_status ~= "pending"
        and normalized_payment_status ~= "paid"
        and normalized_payment_status ~= "unavailable"
        and normalized_payment_status ~= "failed"
    then
        return "pending"
    end

    return normalized_payment_status
end

local function normalize_pickup_status(pickup_status)
    local normalized_pickup_status = trim_string(pickup_status)

    if normalized_pickup_status == nil then
        return "none"
    end

    normalized_pickup_status = string.lower(normalized_pickup_status)

    if normalized_pickup_status ~= "none"
        and normalized_pickup_status ~= "pending"
        and normalized_pickup_status ~= "picked_up"
    then
        return "none"
    end

    return normalized_pickup_status
end

local function normalize_job_source(job_source)
    local normalized_job_source = trim_string(job_source)

    if normalized_job_source == nil then
        return nil
    end

    normalized_job_source = string.lower(normalized_job_source)

    if normalized_job_source ~= "manual"
        and normalized_job_source ~= "route_template"
        and normalized_job_source ~= "job_board"
    then
        return nil
    end

    return normalized_job_source
end

local function normalize_deadline_seconds(deadline_seconds)
    return normalize_positive_integer(deadline_seconds)
end

local function normalize_cargo_cleanup_status(cargo_cleanup_status)
    local normalized_cargo_cleanup_status = trim_string(cargo_cleanup_status)

    if normalized_cargo_cleanup_status == nil then
        return "none"
    end

    normalized_cargo_cleanup_status = string.lower(normalized_cargo_cleanup_status)

    if normalized_cargo_cleanup_status ~= "none"
        and normalized_cargo_cleanup_status ~= "not_required"
        and normalized_cargo_cleanup_status ~= "pending"
        and normalized_cargo_cleanup_status ~= "cleaned"
        and normalized_cargo_cleanup_status ~= "failed"
    then
        return "none"
    end

    return normalized_cargo_cleanup_status
end

local function normalize_rewards_status(rewards_status)
    local normalized_rewards_status = trim_string(rewards_status)

    if normalized_rewards_status == nil then
        return "none"
    end

    normalized_rewards_status = string.lower(normalized_rewards_status)

    if normalized_rewards_status ~= "none"
        and normalized_rewards_status ~= "pending"
        and normalized_rewards_status ~= "granted"
        and normalized_rewards_status ~= "failed"
        and normalized_rewards_status ~= "not_required"
    then
        return "none"
    end

    return normalized_rewards_status
end

local function normalize_cancel_reason(reason, fallback)
    local normalized_reason = trim_string(reason)

    if normalized_reason == nil then
        return fallback
    end

    if #normalized_reason > 255 then
        normalized_reason = normalized_reason:sub(1, 255)
    end

    return normalized_reason
end

local function normalize_item_key(item_key)
    local normalized_item_key = trim_string(item_key)

    if normalized_item_key == nil then
        return nil
    end

    if normalized_item_key:match("^[a-z0-9_]+$") == nil then
        return nil
    end

    return string.lower(normalized_item_key)
end

local function normalize_location_key(location_key)
    local normalized_location_key = trim_string(location_key)

    if normalized_location_key == nil then
        return nil
    end

    if #normalized_location_key > 100 then
        return nil
    end

    if normalized_location_key:match("^[a-z0-9_-]+$") == nil then
        return nil
    end

    return string.lower(normalized_location_key)
end

local function normalize_location_name(name)
    local normalized_name = trim_string(name)

    if normalized_name == nil then
        return nil
    end

    if #normalized_name > 150 then
        return nil
    end

    return normalized_name
end

local function normalize_route_key(route_key)
    local normalized_route_key = trim_string(route_key)

    if normalized_route_key == nil then
        return nil
    end

    if #normalized_route_key > 100 then
        return nil
    end

    if normalized_route_key:match("^[a-z0-9_-]+$") == nil then
        return nil
    end

    return string.lower(normalized_route_key)
end

local function normalize_reward_skill_key(skill_key)
    local skills_config = GRSkills and GRSkills.Shared and GRSkills.Shared.SkillsConfig

    if type(skills_config) == "table" and type(skills_config.NormalizeSkillKey) == "function" then
        return skills_config.NormalizeSkillKey(skill_key)
    end

    return normalize_item_key(skill_key)
end

local function normalize_reward_reputation_key(reputation_key)
    local normalized_reputation_key = trim_string(reputation_key)

    if normalized_reputation_key == nil then
        return nil
    end

    if normalized_reputation_key:match("^[a-z0-9_]+$") == nil then
        return nil
    end

    return string.lower(normalized_reputation_key)
end

local function normalize_required_skill_key(skill_key)
    return normalize_reward_skill_key(skill_key)
end

local function normalize_required_skill_level(skill_level)
    return normalize_non_negative_integer(skill_level)
end

local function normalize_required_reputation_key(reputation_key)
    return normalize_reward_reputation_key(reputation_key)
end

local function normalize_required_reputation_min(reputation_min)
    return normalize_integer(reputation_min)
end

local function normalize_number(value)
    if type(value) == "number" then
        if value ~= value or value == math.huge or value == -math.huge then
            return nil
        end

        return value
    end

    if type(value) == "string" then
        local parsed_value = tonumber(value)

        if parsed_value ~= nil and parsed_value == parsed_value and parsed_value ~= math.huge and parsed_value ~= -math.huge then
            return parsed_value
        end
    end

    return nil
end

local function normalize_boolean_text(value)
    local normalized_value = trim_string(value)

    if normalized_value == nil then
        return nil
    end

    normalized_value = string.lower(normalized_value)

    if normalized_value == "true" then
        return true
    end

    if normalized_value == "false" then
        return false
    end

    return nil
end

local function get_controlled_character(player)
    if type(player) ~= "table" and type(player) ~= "userdata" then
        return nil
    end

    if type(player.GetControlledCharacter) ~= "function" then
        return nil
    end

    return player:GetControlledCharacter()
end

local function get_entity_location(entity)
    if entity == nil or type(entity.GetLocation) ~= "function" then
        return nil
    end

    local location = entity:GetLocation()

    if location == nil then
        return nil
    end

    if type(location.X) ~= "number" or type(location.Y) ~= "number" or type(location.Z) ~= "number" then
        return nil
    end

    return {
        x = location.X,
        y = location.Y,
        z = location.Z,
    }
end

local function get_distance_squared(first_location, second_location)
    if type(first_location) ~= "table" or type(second_location) ~= "table" then
        return nil
    end

    local delta_x = first_location.x - second_location.x
    local delta_y = first_location.y - second_location.y
    local delta_z = first_location.z - second_location.z

    return (delta_x * delta_x) + (delta_y * delta_y) + (delta_z * delta_z)
end

local function build_contract_title(contract_type)
    return CONTRACT_TYPE_TITLES[contract_type] or contract_type
end

local function build_route_contract_description(route_template)
    local route_key = trim_string(route_template and route_template.key) or "unknown_route"
    local route_description = normalize_description(route_template and route_template.description)

    if route_description == nil then
        return string.format("[route:%s] Transport route", tostring(route_key))
    end

    return string.format("[route:%s] %s", tostring(route_key), tostring(route_description))
end

local function is_active_job_contract(contract_row, character_id)
    if type(contract_row) ~= "table" then
        return false
    end

    if normalize_positive_integer(contract_row.assignee_character_id) ~= normalize_positive_integer(character_id) then
        return false
    end

    if trim_string(contract_row.status) ~= "accepted" then
        return false
    end

    if normalize_job_source(contract_row.job_source) == "job_board" then
        return true
    end

    return contract_row.requires_pickup_location == true
end

local function callback_repository_missing(callback)
    if type(callback) == "function" then
        callback(false, nil, "contracts-repository-missing")
    end

    return true
end

local function resolve_economy_bridge()
    if type(GREconomyBridge) ~= "table" then
        return nil
    end

    if type(GREconomyBridge.AddMoney) ~= "function" then
        return nil
    end

    return GREconomyBridge
end

local function resolve_inventory_bridge()
    if type(GRInventoryBridge) ~= "table" then
        return nil
    end

    if type(GRInventoryBridge.ListInventory) ~= "function" then
        return nil
    end

    if type(GRInventoryBridge.RemoveItem) ~= "function" then
        return nil
    end

    if type(GRInventoryBridge.AddItem) ~= "function" then
        return nil
    end

    return GRInventoryBridge
end

local function resolve_skills_bridge()
    if type(GRSkillsBridge) ~= "table" then
        return nil
    end

    if type(GRSkillsBridge.AddSkillXp) ~= "function" or type(GRSkillsBridge.ListSkills) ~= "function" then
        return nil
    end

    return GRSkillsBridge
end

local function resolve_reputation_bridge()
    if type(GRReputationBridge) ~= "table" then
        return nil
    end

    if type(GRReputationBridge.AddReputation) ~= "function" or type(GRReputationBridge.ListCharacterReputations) ~= "function" then
        return nil
    end

    return GRReputationBridge
end

local function resolve_contract_role(contract_row, character_id)
    local normalized_character_id = normalize_positive_integer(character_id)
    local is_creator = false
    local is_assignee = false

    if normalized_character_id == nil or type(contract_row) ~= "table" then
        return "unknown"
    end

    is_creator = normalize_positive_integer(contract_row.creator_character_id) == normalized_character_id
    is_assignee = normalize_positive_integer(contract_row.assignee_character_id) == normalized_character_id

    if is_creator and is_assignee then
        return "creator+assignee"
    end

    if is_assignee then
        return "assignee"
    end

    if is_creator then
        return "creator"
    end

    return "unknown"
end

local function get_platform_id(player)
    if type(player) ~= "table" and type(player) ~= "userdata" then
        return nil
    end

    if type(player.GetAccountID) ~= "function" then
        return nil
    end

    return player:GetAccountID()
end

local function resolve_active_character_id(player_or_character_id)
    local normalized_character_id = normalize_positive_integer(player_or_character_id)

    if normalized_character_id ~= nil then
        return normalized_character_id
    end

    if type(GRCharactersBridge) ~= "table" or type(GRCharactersBridge.GetActiveCharacter) ~= "function" then
        return nil
    end

    local platform_id = get_platform_id(player_or_character_id)

    if platform_id == nil then
        platform_id = trim_string(player_or_character_id)
    end

    if platform_id == nil then
        return nil
    end

    local active_character = GRCharactersBridge.GetActiveCharacter(platform_id)

    if type(active_character) ~= "table" then
        return nil
    end

    return normalize_positive_integer(active_character.id)
end

local function has_required_items(inventory_rows, required_item_key, required_item_quantity)
    local total_quantity = 0

    for _, inventory_row in ipairs(inventory_rows or {}) do
        if inventory_row.item_key == required_item_key then
            total_quantity = total_quantity + (tonumber(inventory_row.quantity) or 0)
        end
    end

    return total_quantity >= required_item_quantity, total_quantity
end

local function is_contract_terminal(contract_row)
    local contract_status = trim_string(contract_row and contract_row.status)
    local payment_status = normalize_payment_status(contract_row and contract_row.payment_status)

    if contract_status == "completed" or contract_status == "cancelled" or contract_status == "expired" then
        return true
    end

    if payment_status == "paid" then
        return true
    end

    return false
end

local function resolve_player_contract_status(contract_row)
    local contract_status = trim_string(contract_row and contract_row.status) or "unknown"
    local pickup_status = normalize_pickup_status(contract_row and contract_row.pickup_status)

    if contract_status == "accepted" and pickup_status == "picked_up" then
        return "picked_up"
    end

    return contract_status
end

local function format_remaining_deadline(remaining_deadline_seconds)
    local normalized_remaining_deadline = normalize_non_negative_integer(remaining_deadline_seconds)

    if normalized_remaining_deadline == nil then
        return "none"
    end

    if normalized_remaining_deadline < 60 then
        return string.format("%ss", tostring(normalized_remaining_deadline))
    end

    if normalized_remaining_deadline < 3600 then
        return string.format("%sm", tostring(math.ceil(normalized_remaining_deadline / 60)))
    end

    if normalized_remaining_deadline < 86400 then
        return string.format("%sh", tostring(math.ceil(normalized_remaining_deadline / 3600)))
    end

    return string.format("%sd", tostring(math.ceil(normalized_remaining_deadline / 86400)))
end

local function build_player_contract_next_action(contract_row)
    local normalized_contract_id = normalize_positive_integer(contract_row and contract_row.id)
    local pickup_location_key = normalize_location_key(contract_row and contract_row.pickup_location_key)
    local delivery_location_key = normalize_location_key(contract_row and contract_row.delivery_location_key)
    local requires_pickup_location = contract_row and contract_row.requires_pickup_location == true
    local requires_delivery_location = contract_row and contract_row.requires_delivery_location == true
    local pickup_status = normalize_pickup_status(contract_row and contract_row.pickup_status)

    if requires_pickup_location and pickup_status == "pending" and pickup_location_key ~= nil and normalized_contract_id ~= nil then
        return string.format(
            "allez au pickup %s puis utilisez /pickupcontract %s",
            tostring(pickup_location_key),
            tostring(normalized_contract_id)
        )
    end

    if requires_delivery_location and delivery_location_key ~= nil and normalized_contract_id ~= nil then
        return string.format(
            "allez a la destination %s puis utilisez /completecontract %s",
            tostring(delivery_location_key),
            tostring(normalized_contract_id)
        )
    end

    if normalized_contract_id ~= nil then
        return string.format("consultez /contractstatus %s", tostring(normalized_contract_id))
    end

    return "consultez les details du contrat"
end

local function build_player_contract_route_label(contract_row)
    local source_route_key = normalize_route_key(contract_row and contract_row.source_route_key)

    if source_route_key ~= nil then
        return source_route_key
    end

    return trim_string(contract_row and contract_row.type) or "contrat"
end

local function enrich_player_active_contract(contract_row)
    local enriched_row = {}

    if type(contract_row) ~= "table" then
        return nil
    end

    for key, value in pairs(contract_row) do
        enriched_row[key] = value
    end

    enriched_row.display_status = resolve_player_contract_status(contract_row)
    enriched_row.deadline_remaining_text = format_remaining_deadline(contract_row.remaining_deadline_seconds)
    enriched_row.next_action = build_player_contract_next_action(contract_row)
    enriched_row.route_label = build_player_contract_route_label(contract_row)

    return enriched_row
end

local function route_has_job_requirements(route_template)
    local required_skill_key = normalize_required_skill_key(route_template and route_template.required_skill_key)
    local required_skill_level = normalize_required_skill_level(route_template and route_template.required_skill_level) or 0
    local required_reputation_key = normalize_required_reputation_key(route_template and route_template.required_reputation_key)
    local required_reputation_min = normalize_required_reputation_min(route_template and route_template.required_reputation_min) or 0

    if required_skill_key ~= nil and required_skill_level > 0 then
        return true
    end

    if required_reputation_key ~= nil and required_reputation_min ~= 0 then
        return true
    end

    return false
end

local function trim_trailing_period(value)
    local normalized_value = trim_string(value)

    if normalized_value == nil then
        return nil
    end

    return normalized_value:gsub("%.$", "")
end

local function normalize_route_availability_reason(reason)
    local normalized_reason = trim_trailing_period(reason)

    if normalized_reason == nil then
        return nil
    end

    if normalized_reason == "skill-unavailable" or normalized_reason == "skills-service-missing" then
        return "service skill indisponible"
    end

    if normalized_reason == "reputation-unavailable" or normalized_reason == "reputation-service-missing" then
        return "service reputation indisponible"
    end

    if normalized_reason == "pickup-location-not-found" or normalized_reason == "pickup-location-key-invalid" then
        return "pickup introuvable"
    end

    if normalized_reason == "pickup-location-inactive" then
        return "pickup inactif"
    end

    if normalized_reason == "delivery-location-not-found" or normalized_reason == "delivery-location-key-invalid" then
        return "destination introuvable"
    end

    if normalized_reason == "delivery-location-inactive" then
        return "destination inactive"
    end

    if normalized_reason == "route-inactive" then
        return "route inactive"
    end

    if normalized_reason == "active-job-limit-reached" then
        return "limite de jobs actifs atteinte"
    end

    if normalized_reason == "skill-service-unavailable" then
        return "service skill indisponible"
    end

    if normalized_reason == "reputation-service-unavailable" then
        return "service reputation indisponible"
    end

    return normalized_reason
end

local function normalize_job_history_limit(value)
    local normalized_limit = normalize_positive_integer(value)

    if normalized_limit == nil then
        return DEFAULT_JOB_HISTORY_LIMIT
    end

    if normalized_limit < 1 then
        return 1
    end

    if normalized_limit > MAX_JOB_HISTORY_LIMIT then
        return MAX_JOB_HISTORY_LIMIT
    end

    return normalized_limit
end

local function translate_route_diagnostic_issue(issue_code)
    if issue_code == "route-key-invalid" then
        return "route_key invalide"
    end

    if issue_code == "item-missing" then
        return "item invalide"
    end

    if issue_code == "quantity-invalid" then
        return "quantite invalide"
    end

    if issue_code == "reward-invalid" then
        return "reward invalide"
    end

    if issue_code == "deadline-invalid" then
        return "deadline invalide"
    end

    if issue_code == "reward-xp-invalid" then
        return "reward xp invalide"
    end

    if issue_code == "requirement-invalid" then
        return "prerequis invalide"
    end

    if issue_code == "pickup-missing" then
        return "pickup introuvable"
    end

    if issue_code == "pickup-inactive" then
        return "pickup inactif"
    end

    if issue_code == "pickup-position-missing" then
        return "pickup non calibre"
    end

    if issue_code == "pickup-radius-invalid" then
        return "pickup radius invalide"
    end

    if issue_code == "delivery-missing" then
        return "destination introuvable"
    end

    if issue_code == "delivery-inactive" then
        return "destination inactive"
    end

    if issue_code == "delivery-position-missing" then
        return "destination non calibree"
    end

    if issue_code == "delivery-radius-invalid" then
        return "destination radius invalide"
    end

    return tostring(issue_code)
end

local function is_location_calibrated(delivery_location)
    local position_x = normalize_number(delivery_location and delivery_location.position_x)
    local position_y = normalize_number(delivery_location and delivery_location.position_y)
    local position_z = normalize_number(delivery_location and delivery_location.position_z)

    return position_x ~= nil and position_y ~= nil and position_z ~= nil
end

local function is_location_radius_valid(delivery_location)
    local radius = normalize_number(delivery_location and delivery_location.radius)

    return radius ~= nil and radius > 0
end

local function table_contains_value(values, expected_value)
    if type(values) ~= "table" or expected_value == nil then
        return false
    end

    for _, value in ipairs(values) do
        if value == expected_value then
            return true
        end
    end

    return false
end

local function add_route_diagnostic_issue(result, issue_code)
    local issue_message = nil

    if type(result) ~= "table" or type(issue_code) ~= "string" then
        return
    end

    result._issue_set = result._issue_set or {}

    if result._issue_set[issue_code] == true then
        return
    end

    result._issue_set[issue_code] = true
    result.issue_codes[#result.issue_codes + 1] = issue_code
    issue_message = translate_route_diagnostic_issue(issue_code)

    if issue_message ~= nil then
        result.issues[#result.issues + 1] = issue_message
    end
end

local function calculate_success_rate_percentage(completed_count, terminal_count)
    local normalized_completed_count = normalize_non_negative_integer(completed_count) or 0
    local normalized_terminal_count = normalize_non_negative_integer(terminal_count) or 0

    if normalized_terminal_count < 1 then
        return 0
    end

    return math.floor(((normalized_completed_count / normalized_terminal_count) * 100) + 0.5)
end

function ContractService.Create(repository)
    local self = setmetatable({}, ContractService)

    self.repository = repository

    return self
end

function ContractService:IsContractExpired(contract_row)
    if type(contract_row) ~= "table" then
        return false
    end

    return trim_string(contract_row.status) == "expired"
end

function ContractService:FinalizeCargoCleanupStatus(contract_row, cargo_cleanup_status, error_message, callback)
    local contract_id = normalize_contract_id(contract_row and contract_row.id)

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if self.repository == nil then
        return callback_repository_missing(callback)
    end

    if contract_id == nil then
        callback(false, nil, "contract-id-invalid")
        return true
    end

    return self.repository:UpdateCargoCleanupStatus(contract_id, cargo_cleanup_status, error_message, function(is_success, updated_row, error)
        if not is_success then
            callback(false, nil, error or "database-error")
            return
        end

        callback(true, updated_row or contract_row, nil)
    end)
end

function ContractService:FinalizeContractRewardsStatus(contract_row, rewards_status, error_message, callback)
    local contract_id = normalize_contract_id(contract_row and contract_row.id)

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if self.repository == nil then
        return callback_repository_missing(callback)
    end

    if contract_id == nil then
        callback(false, nil, "contract-id-invalid")
        return true
    end

    return self.repository:UpdateContractRewardsStatus(contract_id, rewards_status, error_message, function(is_success, updated_row, error)
        if not is_success then
            callback(false, nil, error or "database-error")
            return
        end

        callback(true, updated_row or contract_row, nil)
    end)
end

function ContractService:CleanupExpiredContractCargoRow(contract_row, callback)
    local normalized_contract_id = normalize_contract_id(contract_row and contract_row.id)
    local pickup_status = normalize_pickup_status(contract_row and contract_row.pickup_status)
    local cargo_cleanup_status = normalize_cargo_cleanup_status(contract_row and contract_row.cargo_cleanup_status)
    local required_item_key = normalize_item_key(contract_row and contract_row.required_item_key)
    local required_item_quantity = normalize_positive_integer(contract_row and contract_row.required_item_quantity)
    local assignee_character_id = normalize_positive_integer(contract_row and contract_row.assignee_character_id)
    local inventory_bridge = nil

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if self.repository == nil then
        return callback_repository_missing(callback)
    end

    if normalized_contract_id == nil then
        callback(false, nil, "contract-not-found")
        return true
    end

    if trim_string(contract_row and contract_row.status) ~= "expired" then
        callback(false, contract_row, "contract-not-expired")
        return true
    end

    if cargo_cleanup_status == "cleaned" then
        callback(true, contract_row, nil)
        return true
    end

    if pickup_status ~= "picked_up" then
        return self:FinalizeCargoCleanupStatus(contract_row, "not_required", nil, function(is_finalize_success, updated_row, finalize_error)
            if not is_finalize_success then
                callback(false, contract_row, finalize_error or "database-error")
                return
            end

            callback(false, updated_row, "cargo-not-picked-up")
        end)
    end

    if required_item_key == nil or required_item_quantity == nil or required_item_quantity < 1 then
        return self:FinalizeCargoCleanupStatus(contract_row, "not_required", nil, function(is_finalize_success, updated_row, finalize_error)
            if not is_finalize_success then
                callback(false, contract_row, finalize_error or "database-error")
                return
            end

            callback(true, updated_row, nil)
        end)
    end

    if assignee_character_id == nil then
        return self:FinalizeCargoCleanupStatus(contract_row, "failed", "missing-assignee", function(is_finalize_success, updated_row, finalize_error)
            if not is_finalize_success then
                callback(false, contract_row, finalize_error or "database-error")
                return
            end

            callback(false, updated_row, "missing-assignee")
        end)
    end

    inventory_bridge = resolve_inventory_bridge()

    if inventory_bridge == nil then
        return self:FinalizeCargoCleanupStatus(contract_row, "failed", "inventory-unavailable", function(is_finalize_success, updated_row, finalize_error)
            if not is_finalize_success then
                callback(false, contract_row, finalize_error or "database-error")
                return
            end

            callback(false, updated_row, "inventory-unavailable")
        end)
    end

    return inventory_bridge.ListInventory(assignee_character_id, function(is_list_success, inventory_rows, list_error)
        if not is_list_success then
            self:FinalizeCargoCleanupStatus(contract_row, "failed", "inventory-unavailable", function(is_finalize_success, updated_row, finalize_error)
                if not is_finalize_success then
                    callback(false, contract_row, finalize_error or "database-error")
                    return
                end

                callback(false, updated_row, "inventory-unavailable")
            end)
            return
        end

        local has_items = has_required_items(inventory_rows, required_item_key, required_item_quantity)

        if not has_items then
            self:FinalizeCargoCleanupStatus(contract_row, "failed", "items-missing", function(is_finalize_success, updated_row, finalize_error)
                if not is_finalize_success then
                    callback(false, contract_row, finalize_error or "database-error")
                    return
                end

                callback(false, updated_row, "items-missing")
            end)
            return
        end

        inventory_bridge.RemoveItem(assignee_character_id, required_item_key, required_item_quantity, function(is_remove_success, _, remove_error)
            if not is_remove_success then
                local cleanup_error = "inventory-unavailable"

                if remove_error == "inventory-item-quantity-insufficient" then
                    cleanup_error = "items-missing"
                end

                self:FinalizeCargoCleanupStatus(contract_row, "failed", cleanup_error, function(is_finalize_success, updated_row, finalize_error)
                    if not is_finalize_success then
                        callback(false, contract_row, finalize_error or "database-error")
                        return
                    end

                    callback(false, updated_row, cleanup_error)
                end)
                return
            end

            self:FinalizeCargoCleanupStatus(contract_row, "cleaned", nil, function(is_finalize_success, updated_row, finalize_error)
                if not is_finalize_success then
                    callback(false, contract_row, finalize_error or "database-error")
                    return
                end

                callback(true, updated_row, nil)
            end)
        end)
    end)
end

function ContractService:CleanupExpiredContractCargo(contract_id, callback)
    local normalized_contract_id = normalize_contract_id(contract_id)

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if self.repository == nil then
        return callback_repository_missing(callback)
    end

    if normalized_contract_id == nil then
        callback(false, nil, "contract-id-invalid")
        return true
    end

    return self.repository:GetContractById(normalized_contract_id, function(is_get_success, contract_row, get_error)
        if not is_get_success then
            callback(false, nil, get_error or "database-error")
            return
        end

        if contract_row == nil then
            callback(false, nil, "contract-not-found")
            return
        end

        self:CleanupExpiredContractCargoRow(contract_row, callback)
    end)
end

function ContractService:ListExpiredContracts(callback)
    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if self.repository == nil then
        return callback_repository_missing(callback)
    end

    return self.repository:ListExpiredContracts(callback)
end

function ContractService:EnsureContractNotExpired(contract_row, callback)
    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if type(contract_row) ~= "table" then
        callback(true, contract_row, false, nil)
        return true
    end

    if self:IsContractExpired(contract_row) then
        callback(true, contract_row, true, nil)
        return true
    end

    if contract_row.expires_at == nil then
        callback(true, contract_row, false, nil)
        return true
    end

    return self.repository:MarkContractExpired(contract_row.id, function(is_success, expired_row, error)
        if not is_success then
            callback(false, nil, false, error or "database-error")
            return
        end

        if expired_row ~= nil then
            self:CleanupExpiredContractCargoRow(expired_row, function(_, cleaned_row)
                callback(true, cleaned_row or expired_row, true, nil)
            end)
            return
        end

        callback(true, contract_row, false, nil)
    end)
end

function ContractService:GetContractDeadline(character_id, contract_id, callback)
    local normalized_character_id = normalize_positive_integer(character_id)
    local normalized_contract_id = normalize_contract_id(contract_id)

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if self.repository == nil then
        return callback_repository_missing(callback)
    end

    if normalized_character_id == nil then
        callback(false, nil, "character-id-required")
        return true
    end

    if normalized_contract_id == nil then
        callback(false, nil, "contract-id-invalid")
        return true
    end

    return self.repository:GetContractById(normalized_contract_id, function(is_success, contract_row, error)
        if not is_success then
            callback(false, nil, error or "database-error")
            return
        end

        if contract_row == nil then
            callback(false, nil, "contract-not-found")
            return
        end

        self:EnsureContractNotExpired(contract_row, function(is_deadline_success, resolved_row, is_expired, deadline_error)
            if not is_deadline_success then
                callback(false, nil, deadline_error or "database-error")
                return
            end

            callback(true, resolved_row or contract_row, is_expired and "contract-expired" or nil)
        end)
    end)
end

function ContractService:GetContractRewards(character_id, contract_id, callback)
    local normalized_character_id = normalize_positive_integer(character_id)
    local normalized_contract_id = normalize_contract_id(contract_id)

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if self.repository == nil then
        return callback_repository_missing(callback)
    end

    if normalized_character_id == nil then
        callback(false, nil, "character-id-required")
        return true
    end

    if normalized_contract_id == nil then
        callback(false, nil, "contract-id-invalid")
        return true
    end

    return self.repository:GetContractById(normalized_contract_id, function(is_success, contract_row, error)
        if not is_success then
            callback(false, nil, error or "database-error")
            return
        end

        if contract_row == nil then
            callback(false, nil, "contract-not-found")
            return
        end

        callback(true, contract_row, nil)
    end)
end

function ContractService:GrantContractRewards(contract_id, callback)
    local normalized_contract_id = normalize_contract_id(contract_id)

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if self.repository == nil then
        return callback_repository_missing(callback)
    end

    if normalized_contract_id == nil then
        callback(false, nil, "contract-id-invalid")
        return true
    end

    return self.repository:GetContractById(normalized_contract_id, function(is_success, contract_row, error)
        if not is_success then
            callback(false, nil, error or "database-error")
            return
        end

        if contract_row == nil then
            callback(false, nil, "contract-not-found")
            return
        end

        if trim_string(contract_row.status) ~= "completed" then
            callback(false, contract_row, "contract-not-completed")
            return
        end

        local rewards_status = normalize_rewards_status(contract_row.rewards_status)
        local assignee_character_id = normalize_positive_integer(contract_row.assignee_character_id)
        local reward_skill_key = normalize_reward_skill_key(contract_row.reward_skill_key)
        local reward_skill_xp = normalize_non_negative_integer(contract_row.reward_skill_xp) or 0
        local reward_reputation_key = normalize_reward_reputation_key(contract_row.reward_reputation_key)
        local reward_reputation_delta = normalize_integer(contract_row.reward_reputation_delta) or 0
        local has_skill_reward = reward_skill_key ~= nil and reward_skill_xp > 0
        local has_reputation_reward = reward_reputation_key ~= nil and reward_reputation_delta ~= 0

        if rewards_status == "granted" then
            callback(false, contract_row, "rewards-already-granted")
            return
        end

        if not has_skill_reward and not has_reputation_reward then
            self:FinalizeContractRewardsStatus(contract_row, "not_required", nil, function(is_finalize_success, updated_row, finalize_error)
                if not is_finalize_success then
                    callback(false, contract_row, finalize_error or "database-error")
                    return
                end

                callback(false, updated_row, "rewards-not-required")
            end)
            return
        end

        local function fail_rewards(error_code, error_message)
            return self:FinalizeContractRewardsStatus(contract_row, "failed", error_message or error_code, function(is_finalize_success, updated_row, finalize_error)
                if not is_finalize_success then
                    callback(false, contract_row, finalize_error or "database-error")
                    return
                end

                callback(false, updated_row, error_code)
            end)
        end

        if reward_skill_xp > 0 and reward_skill_key == nil then
            fail_rewards("skill-service-unavailable", "invalid-skill")
            return
        end

        if reward_reputation_delta ~= 0 and reward_reputation_key == nil then
            fail_rewards("reputation-service-unavailable", "invalid-reputation")
            return
        end

        if assignee_character_id == nil then
            fail_rewards("database-error", "missing-assignee")
            return
        end

        local function finish_granted()
            self.repository:MarkContractRewardsGranted(normalized_contract_id, function(is_mark_success, updated_row, mark_error)
                if not is_mark_success then
                    callback(false, contract_row, mark_error or "database-error")
                    return
                end

                callback(true, updated_row or contract_row, nil)
            end)
        end

        local function grant_reputation_reward()
            if not has_reputation_reward then
                finish_granted()
                return
            end

            if reward_reputation_delta < 0 then
                fail_rewards("reputation-service-unavailable", "negative-reputation-disabled")
                return
            end

            local reputation_bridge = resolve_reputation_bridge()

            if reputation_bridge == nil then
                fail_rewards("reputation-service-unavailable", "reputation-unavailable")
                return
            end

            reputation_bridge.AddReputation(
                assignee_character_id,
                reward_reputation_key,
                reward_reputation_delta,
                string.format("contract-reward:%s", tostring(normalized_contract_id)),
                function(is_reputation_success, _, reputation_error)
                    if not is_reputation_success then
                        fail_rewards("reputation-service-unavailable", reputation_error or "reputation-grant-failed")
                        return
                    end

                    finish_granted()
                end
            )
        end

        local function grant_skill_reward()
            if not has_skill_reward then
                grant_reputation_reward()
                return
            end

            local skills_bridge = resolve_skills_bridge()

            if skills_bridge == nil then
                fail_rewards("skill-service-unavailable", "skill-unavailable")
                return
            end

            skills_bridge.AddSkillXp(
                assignee_character_id,
                reward_skill_key,
                reward_skill_xp,
                string.format("contract-reward:%s", tostring(normalized_contract_id)),
                function(is_skill_success, _, skill_error)
                    if not is_skill_success then
                        fail_rewards("skill-service-unavailable", skill_error or "skill-grant-failed")
                        return
                    end

                    grant_reputation_reward()
                end
            )
        end

        grant_skill_reward()
    end)
end

function ContractService:CheckJobRequirements(character_id, route_template, callback)
    local normalized_character_id = normalize_positive_integer(character_id)
    local required_skill_key = normalize_required_skill_key(route_template and route_template.required_skill_key)
    local required_skill_level = normalize_required_skill_level(route_template and route_template.required_skill_level) or 0
    local required_reputation_key = normalize_required_reputation_key(route_template and route_template.required_reputation_key)
    local required_reputation_min = normalize_required_reputation_min(route_template and route_template.required_reputation_min) or 0
    local result = {
        is_met = true,
        missing_requirements = {},
        skill_current_level = nil,
        reputation_current_value = nil,
        route_template = route_template,
        required_skill_key = required_skill_key,
        required_skill_level = required_skill_level,
        required_reputation_key = required_reputation_key,
        required_reputation_min = required_reputation_min,
    }

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if normalized_character_id == nil then
        callback(false, result, "invalid-character")
        return true
    end

    if type(route_template) ~= "table" then
        callback(false, result, "route-not-found")
        return true
    end

    if not route_has_job_requirements(route_template) then
        callback(true, result, nil)
        return true
    end

    local function evaluate_reputation_requirement()
        if required_reputation_key == nil or required_reputation_min == 0 then
            callback(result.is_met, result, result.is_met and nil or "requirements-not-met")
            return
        end

        local reputation_bridge = resolve_reputation_bridge()

        if reputation_bridge == nil then
            callback(false, result, "reputation-service-unavailable")
            return
        end

        reputation_bridge.ListCharacterReputations(normalized_character_id, function(is_success, reputation_rows, error)
            if not is_success then
                callback(false, result, error or "reputation-service-unavailable")
                return
            end

            local current_value = 0

            for _, reputation_row in ipairs(reputation_rows or {}) do
                if normalize_required_reputation_key(reputation_row and reputation_row.key) == required_reputation_key then
                    current_value = normalize_required_reputation_min(reputation_row and reputation_row.value) or 0
                    break
                end
            end

            result.reputation_current_value = current_value

            if current_value < required_reputation_min then
                result.is_met = false
                result.missing_requirements[#result.missing_requirements + 1] = string.format(
                    "reputation %s minimum %s requis, valeur actuelle=%s.",
                    tostring(required_reputation_key),
                    tostring(required_reputation_min),
                    tostring(current_value)
                )
            end

            callback(result.is_met, result, result.is_met and nil or "requirements-not-met")
        end)
    end

    if required_skill_key == nil or required_skill_level < 1 then
        evaluate_reputation_requirement()
        return true
    end

    local skills_bridge = resolve_skills_bridge()

    if skills_bridge == nil then
        callback(false, result, "skill-service-unavailable")
        return true
    end

    return skills_bridge.ListSkills(normalized_character_id, function(is_success, skill_rows, error)
        if not is_success then
            callback(false, result, error or "skill-service-unavailable")
            return
        end

        local current_level = 0

        for _, skill_row in ipairs(skill_rows or {}) do
            if normalize_required_skill_key(skill_row and skill_row.skill_key) == required_skill_key then
                current_level = normalize_required_skill_level(skill_row and skill_row.level) or 0
                break
            end
        end

        result.skill_current_level = current_level

        if current_level < required_skill_level then
            result.is_met = false
            result.missing_requirements[#result.missing_requirements + 1] = string.format(
                "skill %s niveau %s requis, niveau actuel=%s.",
                tostring(required_skill_key),
                tostring(required_skill_level),
                tostring(current_level)
            )
        end

        evaluate_reputation_requirement()
    end)
end

function ContractService:GetJobRequirements(character_id, route_key, callback)
    local normalized_character_id = normalize_positive_integer(character_id)
    local normalized_route_key = normalize_route_key(route_key)

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if self.repository == nil then
        return callback_repository_missing(callback)
    end

    if normalized_character_id == nil then
        callback(false, nil, "invalid-character")
        return true
    end

    if normalized_route_key == nil then
        callback(false, nil, "route-not-found")
        return true
    end

    return self:GetRouteTemplate(normalized_route_key, function(is_success, route_template, error)
        if not is_success then
            callback(false, nil, error or "database-error")
            return
        end

        if route_template == nil then
            callback(false, nil, "route-not-found")
            return
        end

        if route_template.is_active ~= true then
            callback(false, route_template, "route-inactive")
            return
        end

        self:IsRoutePlayable(route_template, function(is_playable_success, playability_result, playability_error)
            if not is_playable_success then
                callback(false, nil, playability_error or "database-error")
                return
            end

            if playability_result == nil or playability_result.is_playable ~= true then
                callback(false, {
                    route_template = route_template,
                    route = route_template,
                    issues = playability_result and playability_result.issues or {},
                    issue_codes = playability_result and playability_result.issue_codes or {},
                }, playability_error or "route-unavailable")
                return
            end

            self:CheckJobRequirements(normalized_character_id, route_template, callback)
        end)
    end)
end

function ContractService:EvaluateJobAvailability(character_id, route_template, callback)
    local normalized_character_id = normalize_positive_integer(character_id)
    local route_key = normalize_route_key(route_template and route_template.key)
    local result = {
        route = route_template,
        is_available = false,
        is_route_playable = false,
        is_technically_unavailable = false,
        route_health = nil,
        reasons = {},
        missing_requirements = {},
        skill_current_level = nil,
        reputation_current_value = nil,
        active_job_count = 0,
        has_active_job_slot = false,
    }

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if self.repository == nil then
        return callback_repository_missing(callback)
    end

    if normalized_character_id == nil then
        callback(false, result, "invalid-character")
        return true
    end

    if type(route_template) ~= "table" or route_key == nil then
        callback(false, result, "route-not-found")
        return true
    end

    result.route = route_template

    if route_template.is_active ~= true then
        result.reasons[#result.reasons + 1] = normalize_route_availability_reason("route-inactive")
        callback(true, result, nil)
        return true
    end

    local function evaluate_requirements()
        self:CheckJobRequirements(normalized_character_id, route_template, function(is_requirements_success, requirements_result, requirements_error)
            if type(requirements_result) == "table" then
                result.missing_requirements = requirements_result.missing_requirements or {}
                result.skill_current_level = requirements_result.skill_current_level
                result.reputation_current_value = requirements_result.reputation_current_value
            end

            if not is_requirements_success then
                if requirements_error == "requirements-not-met" then
                    for _, requirement_message in ipairs(result.missing_requirements) do
                        local normalized_reason = normalize_route_availability_reason(requirement_message)

                        if normalized_reason ~= nil then
                            result.reasons[#result.reasons + 1] = normalized_reason
                        end
                    end
                else
                    result.reasons[#result.reasons + 1] = normalize_route_availability_reason(requirements_error)
                end
            end

            result.is_available = #result.reasons == 0
            callback(true, result, nil)
        end)
    end

    return self:IsRoutePlayable(route_template, function(is_playable_success, playability_result, playability_error)
        if not is_playable_success then
            callback(false, nil, playability_error or "database-error")
            return
        end

        result.route_health = playability_result

        if playability_result == nil or playability_result.is_playable ~= true then
            result.is_route_playable = false
            result.is_technically_unavailable = true

            for _, issue_text in ipairs((playability_result and playability_result.issues) or {}) do
                result.reasons[#result.reasons + 1] = normalize_route_availability_reason(issue_text)
            end

            callback(true, result, nil)
            return
        end

        result.is_route_playable = true

        self.repository:ListContractsForCharacter(normalized_character_id, function(is_list_success, contract_rows, list_error)
            if not is_list_success then
                callback(false, nil, list_error or "database-error")
                return
            end

            for _, contract_row in ipairs(contract_rows or {}) do
                if is_active_job_contract(contract_row, normalized_character_id) then
                    result.active_job_count = result.active_job_count + 1
                end
            end

            result.has_active_job_slot = result.active_job_count < MAX_ACTIVE_JOB_CONTRACTS

            if not result.has_active_job_slot then
                result.reasons[#result.reasons + 1] = normalize_route_availability_reason("active-job-limit-reached")
            end

            evaluate_requirements()
        end)
    end)
end

function ContractService:GetAvailableJobs(character_id, callback)
    local normalized_character_id = normalize_positive_integer(character_id)

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if self.repository == nil then
        return callback_repository_missing(callback)
    end

    if normalized_character_id == nil then
        callback(false, nil, "invalid-character")
        return true
    end

    return self:ListRouteTemplates(function(is_success, route_templates, error)
        if not is_success then
            callback(false, nil, error or "database-error")
            return
        end

        local available_routes = {}
        local index = 1

        local function finish()
            callback(true, available_routes, nil)
        end

        local function process_next()
            if index > #(route_templates or {}) then
                finish()
                return
            end

            local route_template = route_templates[index]
            index = index + 1

            self:EvaluateJobAvailability(normalized_character_id, route_template, function(is_evaluation_success, availability_result, evaluation_error)
                if not is_evaluation_success then
                    callback(false, nil, evaluation_error or "database-error")
                    return
                end

                if availability_result ~= nil and availability_result.is_available == true then
                    available_routes[#available_routes + 1] = availability_result
                end

                process_next()
            end)
        end

        process_next()
    end)
end

function ContractService:GetLockedJobs(character_id, callback)
    local normalized_character_id = normalize_positive_integer(character_id)

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if self.repository == nil then
        return callback_repository_missing(callback)
    end

    if normalized_character_id == nil then
        callback(false, nil, "invalid-character")
        return true
    end

    return self:ListRouteTemplates(function(is_success, route_templates, error)
        if not is_success then
            callback(false, nil, error or "database-error")
            return
        end

        local locked_routes = {}
        local index = 1

        local function finish()
            callback(true, locked_routes, nil)
        end

        local function process_next()
            if index > #(route_templates or {}) then
                finish()
                return
            end

            local route_template = route_templates[index]
            index = index + 1

            self:EvaluateJobAvailability(normalized_character_id, route_template, function(is_evaluation_success, availability_result, evaluation_error)
                if not is_evaluation_success then
                    callback(false, nil, evaluation_error or "database-error")
                    return
                end

                if availability_result ~= nil and availability_result.is_available ~= true then
                    locked_routes[#locked_routes + 1] = availability_result
                end

                process_next()
            end)
        end

        process_next()
    end)
end

function ContractService:GetJobProgress(character_id, callback)
    local normalized_character_id = normalize_positive_integer(character_id)

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if self.repository == nil then
        return callback_repository_missing(callback)
    end

    if normalized_character_id == nil then
        callback(false, nil, "invalid-character")
        return true
    end

    return self:ListRouteTemplates(function(is_routes_success, route_templates, routes_error)
        if not is_routes_success then
            callback(false, nil, routes_error or "database-error")
            return
        end

        local required_skill_keys = {}
        local required_skill_entries = {}

        for _, route_template in ipairs(route_templates or {}) do
            local required_skill_key = normalize_required_skill_key(route_template and route_template.required_skill_key)
            local required_skill_level = normalize_required_skill_level(route_template and route_template.required_skill_level) or 0

            if required_skill_key ~= nil and required_skill_level > 0 and required_skill_keys[required_skill_key] ~= true then
                required_skill_keys[required_skill_key] = true
                required_skill_entries[#required_skill_entries + 1] = {
                    skill_key = required_skill_key,
                    level = 0,
                    xp = 0,
                }
            end
        end

        local function resolve_active_jobs_and_counts()
            self.repository:ListContractsForCharacter(normalized_character_id, function(is_list_success, contract_rows, list_error)
                if not is_list_success then
                    callback(false, nil, list_error or "database-error")
                    return
                end

                local active_job_count = 0

                for _, contract_row in ipairs(contract_rows or {}) do
                    if is_active_job_contract(contract_row, normalized_character_id) then
                        active_job_count = active_job_count + 1
                    end
                end

                self:GetAvailableJobs(normalized_character_id, function(is_available_success, available_rows, available_error)
                    if not is_available_success then
                        callback(false, nil, available_error or "database-error")
                        return
                    end

                    self:GetLockedJobs(normalized_character_id, function(is_locked_success, locked_rows, locked_error)
                        if not is_locked_success then
                            callback(false, nil, locked_error or "database-error")
                            return
                        end

                        callback(true, {
                            skills = required_skill_entries,
                            has_required_skills = #required_skill_entries > 0,
                            available_count = #(available_rows or {}),
                            locked_count = #(locked_rows or {}),
                            active_job_count = active_job_count,
                            max_active_job_count = MAX_ACTIVE_JOB_CONTRACTS,
                        }, nil)
                    end)
                end)
            end)
        end

        if #required_skill_entries == 0 then
            resolve_active_jobs_and_counts()
            return
        end

        local skills_bridge = resolve_skills_bridge()

        if skills_bridge == nil then
            callback(false, nil, "skill-service-unavailable")
            return
        end

        skills_bridge.ListSkills(normalized_character_id, function(is_skills_success, skill_rows, skills_error)
            if not is_skills_success then
                callback(false, nil, skills_error or "skill-service-unavailable")
                return
            end

            local skill_row_map = {}

            for _, skill_row in ipairs(skill_rows or {}) do
                local skill_key = normalize_required_skill_key(skill_row and skill_row.skill_key)

                if skill_key ~= nil then
                    skill_row_map[skill_key] = skill_row
                end
            end

            for _, skill_entry in ipairs(required_skill_entries) do
                local skill_row = skill_row_map[skill_entry.skill_key]

                if type(skill_row) == "table" then
                    skill_entry.level = normalize_required_skill_level(skill_row.level) or 0
                    skill_entry.xp = normalize_non_negative_integer(skill_row.total_xp) or 0
                end
            end

            resolve_active_jobs_and_counts()
        end)
    end)
end

function ContractService:GetJobUnlocks(character_id, callback)
    local normalized_character_id = normalize_positive_integer(character_id)

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if self.repository == nil then
        return callback_repository_missing(callback)
    end

    if normalized_character_id == nil then
        callback(false, nil, "invalid-character")
        return true
    end

    return self:GetLockedJobs(normalized_character_id, function(is_locked_success, locked_rows, locked_error)
        if not is_locked_success then
            callback(false, nil, locked_error or "database-error")
            return
        end

        local unlock_rows = {}

        for _, availability_result in ipairs(locked_rows or {}) do
            local unlock_reasons = {}
            local missing_requirements = availability_result and availability_result.missing_requirements or {}
            local reasons = availability_result and availability_result.reasons or {}

            for _, requirement_message in ipairs(missing_requirements or {}) do
                local normalized_reason = trim_trailing_period(requirement_message)

                if normalized_reason ~= nil then
                    unlock_reasons[#unlock_reasons + 1] = normalized_reason
                end
            end

            if #unlock_reasons == 0 then
                for _, reason in ipairs(reasons or {}) do
                    if reason == "service skill indisponible" or reason == "service reputation indisponible" then
                        unlock_reasons[#unlock_reasons + 1] = reason
                    end
                end
            end

            if #unlock_reasons > 0 then
                availability_result.unlock_reasons = unlock_reasons
                unlock_rows[#unlock_rows + 1] = availability_result
            end
        end

        callback(true, unlock_rows, nil)
    end)
end

function ContractService:GetJobStats(character_id, callback)
    local normalized_character_id = normalize_positive_integer(character_id)

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if self.repository == nil then
        return callback_repository_missing(callback)
    end

    if normalized_character_id == nil then
        callback(false, nil, "invalid-character")
        return true
    end

    return self.repository:GetCharacterJobStats(normalized_character_id, function(is_success, job_stats_row, error)
        if not is_success then
            callback(false, nil, error or "database-error")
            return
        end

        local normalized_job_stats = job_stats_row or {}
        local completed_count = normalize_non_negative_integer(normalized_job_stats.completed_count) or 0
        local active_count = normalize_non_negative_integer(normalized_job_stats.active_count) or 0
        local cancelled_count = normalize_non_negative_integer(normalized_job_stats.cancelled_count) or 0
        local abandoned_count = normalize_non_negative_integer(normalized_job_stats.abandoned_count) or 0
        local expired_count = normalize_non_negative_integer(normalized_job_stats.expired_count) or 0
        local terminal_count = normalize_non_negative_integer(normalized_job_stats.terminal_count) or 0
        local money_earned = normalize_non_negative_integer(normalized_job_stats.money_earned) or 0
        local granted_skill_xp = normalize_non_negative_integer(normalized_job_stats.granted_skill_xp) or 0

        callback(true, {
            completed_count = completed_count,
            active_count = active_count,
            cancelled_count = cancelled_count,
            abandoned_count = abandoned_count,
            abandoned_or_cancelled_count = cancelled_count,
            expired_count = expired_count,
            terminal_count = terminal_count,
            money_earned = money_earned,
            granted_skill_xp = granted_skill_xp,
            success_rate_percentage = calculate_success_rate_percentage(completed_count, terminal_count),
        }, nil)
    end)
end

function ContractService:GetJobHistory(character_id, limit, callback)
    local normalized_character_id = normalize_positive_integer(character_id)
    local normalized_limit = normalize_job_history_limit(limit)

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if self.repository == nil then
        return callback_repository_missing(callback)
    end

    if normalized_character_id == nil then
        callback(false, nil, "invalid-character")
        return true
    end

    return self.repository:ListCharacterJobHistory(normalized_character_id, normalized_limit, function(is_success, contract_rows, error)
        if not is_success then
            callback(false, nil, error or "database-error")
            return
        end

        callback(true, {
            limit = normalized_limit,
            rows = contract_rows or {},
        }, nil)
    end)
end

function ContractService:ExpireContracts(callback)
    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if self.repository == nil then
        return callback_repository_missing(callback)
    end

    return self.repository:MarkExpiredContracts(function(is_success, expired_count, expired_rows, error)
        if not is_success then
            callback(false, nil, nil, error or "database-error")
            return
        end

        local summary = {
            expired_count = expired_count or 0,
            cleanup_cleaned_count = 0,
            cleanup_failed_count = 0,
            cleanup_not_required_count = 0,
            expired_rows = {},
        }
        local rows = expired_rows or {}
        local index = 1

        local function finish()
            callback(true, summary, nil)
        end

        local function process_next()
            if index > #rows then
                finish()
                return
            end

            local expired_row = rows[index]
            index = index + 1

            self:CleanupExpiredContractCargoRow(expired_row, function(is_cleanup_success, updated_row, cleanup_error)
                local resolved_row = updated_row or expired_row
                local cleanup_status = normalize_cargo_cleanup_status(resolved_row and resolved_row.cargo_cleanup_status)

                summary.expired_rows[#summary.expired_rows + 1] = resolved_row

                if cleanup_status == "cleaned" then
                    summary.cleanup_cleaned_count = summary.cleanup_cleaned_count + 1
                elseif cleanup_status == "not_required" then
                    summary.cleanup_not_required_count = summary.cleanup_not_required_count + 1
                elseif cleanup_status == "failed" then
                    summary.cleanup_failed_count = summary.cleanup_failed_count + 1
                elseif not is_cleanup_success and cleanup_error ~= nil then
                    summary.cleanup_failed_count = summary.cleanup_failed_count + 1
                end

                process_next()
            end)
        end

        process_next()
    end)
end

function ContractService:CreateContract(character_id, contract_type, reward_money, description, callback)
    local normalized_character_id = normalize_positive_integer(character_id)
    local normalized_contract_type = normalize_contract_type(contract_type)
    local normalized_reward_money = normalize_reward_money(reward_money)
    local normalized_description = normalize_description(description)

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if self.repository == nil then
        return callback_repository_missing(callback)
    end

    if normalized_character_id == nil then
        callback(false, nil, "character-id-required")
        return true
    end

    if normalized_contract_type == nil then
        callback(false, nil, "contract-type-invalid")
        return true
    end

    if normalized_reward_money == nil then
        callback(false, nil, "reward-money-invalid")
        return true
    end

    if normalized_description == nil then
        callback(false, nil, "description-invalid")
        return true
    end

    return self.repository:CreateContract({
        creator_character_id = normalized_character_id,
        type = normalized_contract_type,
        title = build_contract_title(normalized_contract_type),
        description = normalized_description,
        reward_money = normalized_reward_money,
        deadline_at = nil,
        required_item_key = nil,
        required_item_quantity = 0,
        consume_required_items = true,
        source_route_key = nil,
        job_source = "manual",
    }, function(is_success, contract_row, error)
        if not is_success then
            callback(false, nil, error)
            return
        end

        Console.Log(
            "[gr_contracts][service] Contract created id=%s creator_character_id=%s type=%s reward_money=%s.",
            tostring(contract_row and contract_row.id),
            tostring(normalized_character_id),
            tostring(normalized_contract_type),
            tostring(normalized_reward_money)
        )

        callback(true, contract_row, nil)
    end)
end

function ContractService:CreateDeliveryContract(creator_character_id, item_key, quantity, reward_money, description, callback)
    local normalized_character_id = normalize_positive_integer(creator_character_id)
    local normalized_item_key = normalize_item_key(item_key)
    local normalized_quantity = normalize_positive_integer(quantity)
    local normalized_reward_money = normalize_reward_money(reward_money)
    local normalized_description = normalize_description(description)

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if self.repository == nil then
        return callback_repository_missing(callback)
    end

    if normalized_character_id == nil then
        callback(false, nil, "character-id-required")
        return true
    end

    if normalized_item_key == nil then
        callback(false, nil, "item-key-invalid")
        return true
    end

    if normalized_quantity == nil or normalized_quantity > MAX_DELIVERY_QUANTITY then
        callback(false, nil, "quantity-invalid")
        return true
    end

    if normalized_reward_money == nil then
        callback(false, nil, "reward-money-invalid")
        return true
    end

    if normalized_description == nil then
        callback(false, nil, "description-invalid")
        return true
    end

    return self.repository:CreateContract({
        creator_character_id = normalized_character_id,
        type = "delivery",
        title = build_contract_title("delivery"),
        description = normalized_description,
        reward_money = normalized_reward_money,
        deadline_at = nil,
        required_item_key = normalized_item_key,
        required_item_quantity = normalized_quantity,
        consume_required_items = true,
        pickup_location_key = nil,
        requires_pickup_location = false,
        pickup_status = "none",
        delivery_location_key = nil,
        requires_delivery_location = false,
        source_route_key = nil,
        job_source = "manual",
    }, function(is_success, contract_row, error)
        if not is_success then
            callback(false, nil, error)
            return
        end

        Console.Log(
            "[gr_contracts][service] Delivery contract created id=%s creator_character_id=%s item=%s quantity=%s reward_money=%s.",
            tostring(contract_row and contract_row.id),
            tostring(normalized_character_id),
            tostring(normalized_item_key),
            tostring(normalized_quantity),
            tostring(normalized_reward_money)
        )

        callback(true, contract_row, nil)
    end)
end

function ContractService:CreateDeliveryContractAt(creator_character_id, item_key, quantity, reward_money, location_key, description, callback)
    local normalized_character_id = normalize_positive_integer(creator_character_id)
    local normalized_item_key = normalize_item_key(item_key)
    local normalized_quantity = normalize_positive_integer(quantity)
    local normalized_reward_money = normalize_reward_money(reward_money)
    local normalized_location_key = normalize_location_key(location_key)
    local normalized_description = normalize_description(description)

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if self.repository == nil then
        return callback_repository_missing(callback)
    end

    if normalized_character_id == nil then
        callback(false, nil, "character-id-required")
        return true
    end

    if normalized_item_key == nil then
        callback(false, nil, "item-key-invalid")
        return true
    end

    if normalized_quantity == nil or normalized_quantity > MAX_DELIVERY_QUANTITY then
        callback(false, nil, "quantity-invalid")
        return true
    end

    if normalized_reward_money == nil then
        callback(false, nil, "reward-money-invalid")
        return true
    end

    if normalized_location_key == nil then
        callback(false, nil, "delivery-location-key-invalid")
        return true
    end

    if normalized_description == nil then
        callback(false, nil, "description-invalid")
        return true
    end

    return self.repository:GetDeliveryLocation(normalized_location_key, function(is_location_success, delivery_location, location_error)
        if not is_location_success then
            callback(false, nil, location_error or "delivery-location-not-found")
            return
        end

        if delivery_location == nil then
            callback(false, nil, "delivery-location-not-found")
            return
        end

        if delivery_location.is_active ~= true then
            callback(false, nil, "delivery-location-inactive")
            return
        end

        self.repository:CreateContract({
            creator_character_id = normalized_character_id,
            type = "delivery",
            title = build_contract_title("delivery"),
            description = normalized_description,
            reward_money = normalized_reward_money,
            deadline_at = nil,
            required_item_key = normalized_item_key,
            required_item_quantity = normalized_quantity,
            consume_required_items = true,
            pickup_location_key = nil,
            requires_pickup_location = false,
            pickup_status = "none",
            delivery_location_key = normalized_location_key,
            requires_delivery_location = true,
            source_route_key = nil,
            job_source = "manual",
        }, function(is_success, contract_row, error)
            if not is_success then
                callback(false, nil, error)
                return
            end

            Console.Log(
                "[gr_contracts][service] Delivery contract with location created id=%s creator_character_id=%s item=%s quantity=%s reward_money=%s location=%s.",
                tostring(contract_row and contract_row.id),
                tostring(normalized_character_id),
                tostring(normalized_item_key),
                tostring(normalized_quantity),
                tostring(normalized_reward_money),
                tostring(normalized_location_key)
            )

            callback(true, contract_row, nil)
        end)
    end)
end

function ContractService:CreateHaulContract(creator_character_id, item_key, quantity, reward_money, pickup_location_key, delivery_location_key, description, options_or_callback, callback)
    local normalized_character_id = normalize_positive_integer(creator_character_id)
    local normalized_item_key = normalize_item_key(item_key)
    local normalized_quantity = normalize_positive_integer(quantity)
    local normalized_reward_money = normalize_reward_money(reward_money)
    local normalized_pickup_location_key = normalize_location_key(pickup_location_key)
    local normalized_delivery_location_key = normalize_location_key(delivery_location_key)
    local normalized_description = normalize_description(description)
    local options = nil
    local normalized_source_route_key = nil
    local normalized_job_source = "manual"
    local normalized_deadline_seconds = nil
    local normalized_reward_skill_key = nil
    local normalized_reward_skill_xp = 0
    local normalized_reward_reputation_key = nil
    local normalized_reward_reputation_delta = 0
    local normalized_rewards_status = "not_required"

    if type(options_or_callback) == "function" and callback == nil then
        callback = options_or_callback
    elseif type(options_or_callback) == "table" then
        options = options_or_callback
    end

    normalized_source_route_key = normalize_route_key(options and options.source_route_key)
    normalized_job_source = normalize_job_source(options and options.job_source) or "manual"
    normalized_deadline_seconds = normalize_deadline_seconds(options and options.deadline_seconds)
    normalized_reward_skill_key = normalize_reward_skill_key(options and options.reward_skill_key)
    normalized_reward_skill_xp = normalize_non_negative_integer(options and options.reward_skill_xp) or 0
    normalized_reward_reputation_key = normalize_reward_reputation_key(options and options.reward_reputation_key)
    normalized_reward_reputation_delta = normalize_integer(options and options.reward_reputation_delta) or 0

    if normalized_reward_skill_key ~= nil and normalized_reward_skill_xp > 0 then
        normalized_rewards_status = "pending"
    end

    if normalized_reward_reputation_key ~= nil and normalized_reward_reputation_delta ~= 0 then
        normalized_rewards_status = "pending"
    end

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if self.repository == nil then
        return callback_repository_missing(callback)
    end

    if normalized_character_id == nil then
        callback(false, nil, "character-id-required")
        return true
    end

    if normalized_item_key == nil then
        callback(false, nil, "item-key-invalid")
        return true
    end

    if normalized_quantity == nil or normalized_quantity > MAX_DELIVERY_QUANTITY then
        callback(false, nil, "quantity-invalid")
        return true
    end

    if normalized_reward_money == nil then
        callback(false, nil, "reward-money-invalid")
        return true
    end

    if normalized_pickup_location_key == nil then
        callback(false, nil, "pickup-location-key-invalid")
        return true
    end

    if normalized_delivery_location_key == nil then
        callback(false, nil, "delivery-location-key-invalid")
        return true
    end

    if normalized_description == nil then
        callback(false, nil, "description-invalid")
        return true
    end

    if normalized_source_route_key == nil and normalized_job_source ~= "manual" then
        callback(false, nil, "source-route-key-invalid")
        return true
    end

    if options ~= nil and options.deadline_seconds ~= nil and normalized_deadline_seconds == nil then
        callback(false, nil, "deadline-seconds-invalid")
        return true
    end

    if options ~= nil and options.reward_skill_key ~= nil and normalized_reward_skill_key == nil then
        callback(false, nil, "reward-skill-key-invalid")
        return true
    end

    if options ~= nil and options.reward_skill_xp ~= nil and normalize_non_negative_integer(options.reward_skill_xp) == nil then
        callback(false, nil, "reward-skill-xp-invalid")
        return true
    end

    if options ~= nil and options.reward_reputation_key ~= nil and normalized_reward_reputation_key == nil then
        callback(false, nil, "reward-reputation-key-invalid")
        return true
    end

    if options ~= nil and options.reward_reputation_delta ~= nil and normalize_integer(options.reward_reputation_delta) == nil then
        callback(false, nil, "reward-reputation-delta-invalid")
        return true
    end

    return self.repository:GetDeliveryLocation(normalized_pickup_location_key, function(is_pickup_success, pickup_location, pickup_error)
        if not is_pickup_success then
            callback(false, nil, pickup_error or "pickup-location-not-found")
            return
        end

        if pickup_location == nil then
            callback(false, nil, "pickup-location-not-found")
            return
        end

        if pickup_location.is_active ~= true then
            callback(false, nil, "pickup-location-inactive")
            return
        end

        self.repository:GetDeliveryLocation(normalized_delivery_location_key, function(is_delivery_success, delivery_location, delivery_error)
            if not is_delivery_success then
                callback(false, nil, delivery_error or "delivery-location-not-found")
                return
            end

            if delivery_location == nil then
                callback(false, nil, "delivery-location-not-found")
                return
            end

            if delivery_location.is_active ~= true then
                callback(false, nil, "delivery-location-inactive")
                return
            end

            self.repository:CreateContract({
                creator_character_id = normalized_character_id,
                type = "delivery",
                title = build_contract_title("delivery"),
                description = normalized_description,
                reward_money = normalized_reward_money,
                reward_skill_key = normalized_reward_skill_key,
                reward_skill_xp = normalized_reward_skill_xp,
                reward_reputation_key = normalized_reward_reputation_key,
                reward_reputation_delta = normalized_reward_reputation_delta,
                rewards_status = normalized_rewards_status,
                deadline_at = nil,
                required_item_key = normalized_item_key,
                required_item_quantity = normalized_quantity,
                consume_required_items = true,
                pickup_location_key = normalized_pickup_location_key,
                requires_pickup_location = true,
                pickup_status = "pending",
                delivery_location_key = normalized_delivery_location_key,
                requires_delivery_location = true,
                deadline_seconds = normalized_deadline_seconds,
                source_route_key = normalized_source_route_key,
                job_source = normalized_job_source,
            }, function(is_success, contract_row, error)
                if not is_success then
                    callback(false, nil, error)
                    return
                end

                Console.Log(
                    "[gr_contracts][service] Haul contract created id=%s creator_character_id=%s item=%s quantity=%s reward_money=%s pickup=%s delivery=%s.",
                    tostring(contract_row and contract_row.id),
                    tostring(normalized_character_id),
                    tostring(normalized_item_key),
                    tostring(normalized_quantity),
                    tostring(normalized_reward_money),
                    tostring(normalized_pickup_location_key),
                    tostring(normalized_delivery_location_key)
                )

                callback(true, contract_row, nil)
            end)
        end)
    end)
end

function ContractService:CreateHaulContractFromRoute(creator_character_id, route_key, callback)
    local normalized_character_id = normalize_positive_integer(creator_character_id)
    local normalized_route_key = normalize_route_key(route_key)

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if self.repository == nil then
        return callback_repository_missing(callback)
    end

    if normalized_character_id == nil then
        callback(false, nil, "invalid-character")
        return true
    end

    if normalized_route_key == nil then
        callback(false, nil, "route-not-found")
        return true
    end

    return self.repository:GetRouteTemplate(normalized_route_key, function(is_success, route_template, error)
        if not is_success then
            callback(false, nil, error or "database-error")
            return
        end

        if route_template == nil then
            callback(false, nil, "route-not-found")
            return
        end

        if route_template.is_active ~= true then
            callback(false, route_template, "route-inactive")
            return
        end

        self:IsRoutePlayable(route_template, function(is_playable_success, playability_result, playability_error)
            if not is_playable_success then
                callback(false, nil, playability_error or "database-error")
                return
            end

            if playability_result == nil or playability_result.is_playable ~= true then
                callback(false, playability_result, playability_error or "route-unavailable")
                return
            end

            self:CreateHaulContract(
                normalized_character_id,
                route_template.item_key,
                route_template.item_quantity,
                route_template.reward_money,
                route_template.pickup_location_key,
                route_template.delivery_location_key,
                build_route_contract_description(route_template),
                {
                    source_route_key = route_template.key,
                    job_source = "route_template",
                    deadline_seconds = route_template.deadline_seconds,
                    reward_skill_key = route_template.reward_skill_key,
                    reward_skill_xp = route_template.reward_skill_xp,
                    reward_reputation_key = route_template.reward_reputation_key,
                    reward_reputation_delta = route_template.reward_reputation_delta,
                },
                function(is_create_success, contract_row, create_error)
                    if not is_create_success then
                        callback(false, route_template, create_error)
                        return
                    end

                    if type(contract_row) == "table" then
                        contract_row.route_key = route_template.key
                        contract_row.route_name = route_template.name
                    end

                    callback(true, contract_row, nil)
                end
            )
        end)
    end)
end

function ContractService:ListDeliveryLocations(callback)
    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if self.repository == nil then
        return callback_repository_missing(callback)
    end

    return self.repository:ListDeliveryLocations(callback)
end

function ContractService:ListAllContractLocations(callback)
    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if self.repository == nil then
        return callback_repository_missing(callback)
    end

    return self.repository:ListAllContractLocations(callback)
end

function ContractService:ListRouteTemplates(callback)
    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if self.repository == nil then
        return callback_repository_missing(callback)
    end

    return self.repository:ListRouteTemplates(function(is_success, route_templates, error)
        local active_route_templates = {}

        if not is_success then
            callback(false, nil, error)
            return
        end

        for _, route_template in ipairs(route_templates or {}) do
            if route_template.is_active == true then
                active_route_templates[#active_route_templates + 1] = route_template
            end
        end

        callback(true, active_route_templates, nil)
    end)
end

function ContractService:GetRouteTemplate(route_key, callback)
    local normalized_route_key = normalize_route_key(route_key)

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if self.repository == nil then
        return callback_repository_missing(callback)
    end

    if normalized_route_key == nil then
        callback(false, nil, "route-not-found")
        return true
    end

    return self.repository:GetRouteTemplate(normalized_route_key, function(is_success, route_template, error)
        if not is_success then
            callback(false, nil, error or "database-error")
            return
        end

        if route_template == nil then
            callback(false, nil, "route-not-found")
            return
        end

        callback(true, route_template, nil)
    end)
end

function ContractService:CreateRouteTemplate(route_key, item_key, quantity, reward_money, pickup_location_key, delivery_location_key, description, callback)
    local normalized_route_key = normalize_route_key(route_key)
    local normalized_item_key = normalize_item_key(item_key)
    local normalized_quantity = normalize_positive_integer(quantity)
    local normalized_reward_money = normalize_reward_money(reward_money)
    local normalized_pickup_location_key = normalize_location_key(pickup_location_key)
    local normalized_delivery_location_key = normalize_location_key(delivery_location_key)
    local normalized_description = normalize_description(description)

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if self.repository == nil then
        return callback_repository_missing(callback)
    end

    if normalized_route_key == nil then
        callback(false, nil, "invalid-route-key")
        return true
    end

    if normalized_item_key == nil then
        callback(false, nil, "invalid-item-key")
        return true
    end

    if normalized_quantity == nil or normalized_quantity > MAX_DELIVERY_QUANTITY then
        callback(false, nil, "invalid-quantity")
        return true
    end

    if normalized_reward_money == nil then
        callback(false, nil, "invalid-reward")
        return true
    end

    if normalized_pickup_location_key == nil then
        callback(false, nil, "invalid-pickup-location")
        return true
    end

    if normalized_delivery_location_key == nil then
        callback(false, nil, "invalid-delivery-location")
        return true
    end

    if normalized_description == nil then
        callback(false, nil, "invalid-description")
        return true
    end

    return self:GetRouteTemplate(normalized_route_key, function(is_route_success, existing_route_template, route_error)
        if is_route_success and existing_route_template ~= nil then
            callback(false, existing_route_template, "route-already-exists")
            return
        end

        if not is_route_success and route_error ~= "route-not-found" then
            callback(false, nil, route_error or "database-error")
            return
        end

        self.repository:GetDeliveryLocation(normalized_pickup_location_key, function(is_pickup_success, pickup_location, pickup_error)
            if not is_pickup_success then
                callback(false, nil, pickup_error or "invalid-pickup-location")
                return
            end

            if pickup_location == nil or pickup_location.is_active ~= true then
                callback(false, nil, "invalid-pickup-location")
                return
            end

            self.repository:GetDeliveryLocation(normalized_delivery_location_key, function(is_delivery_success, delivery_location, delivery_error)
                if not is_delivery_success then
                    callback(false, nil, delivery_error or "invalid-delivery-location")
                    return
                end

                if delivery_location == nil or delivery_location.is_active ~= true then
                    callback(false, nil, "invalid-delivery-location")
                    return
                end

                self.repository:CreateRouteTemplate({
                    key = normalized_route_key,
                    name = normalized_route_key,
                    description = normalized_description,
                    item_key = normalized_item_key,
                    item_quantity = normalized_quantity,
                    reward_money = normalized_reward_money,
                    pickup_location_key = normalized_pickup_location_key,
                    delivery_location_key = normalized_delivery_location_key,
                    is_active = false,
                }, function(is_create_success, route_template, create_error)
                    if not is_create_success then
                        if create_error == "route-already-exists" then
                            callback(false, nil, "route-already-exists")
                            return
                        end

                        callback(false, nil, create_error or "database-error")
                        return
                    end

                    if route_template == nil then
                        callback(false, nil, "database-error")
                        return
                    end

                    callback(true, route_template, nil)
                end)
            end)
        end)
    end)
end

function ContractService:SetRouteDescription(route_key, description, callback)
    local normalized_route_key = normalize_route_key(route_key)
    local normalized_description = normalize_description(description)

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if self.repository == nil then
        return callback_repository_missing(callback)
    end

    if normalized_route_key == nil then
        callback(false, nil, "invalid-route-key")
        return true
    end

    if normalized_description == nil then
        callback(false, nil, "invalid-description")
        return true
    end

    return self.repository:UpdateRouteDescription(normalized_route_key, normalized_description, function(is_success, route_template, error)
        if not is_success then
            callback(false, nil, error or "database-error")
            return
        end

        if route_template == nil then
            callback(false, nil, "route-not-found")
            return
        end

        callback(true, route_template, nil)
    end)
end

function ContractService:EvaluateRouteTemplateHealth(route_template, pickup_location, delivery_location, raw_route)
    local result = {
        route = route_template,
        pickup_location = pickup_location,
        delivery_location = delivery_location,
        is_valid = true,
        issues = {},
        issue_codes = {},
        is_uncalibrated = false,
        item_catalog_verified = false,
    }
    local normalized_required_reputation_min = normalize_required_reputation_min(raw_route and raw_route.required_reputation_min)
    local raw_item_quantity = raw_route ~= nil and raw_route.item_quantity or (route_template and route_template.item_quantity)
    local raw_reward_money = raw_route ~= nil and raw_route.reward_money or (route_template and route_template.reward_money)
    local raw_deadline_seconds = raw_route ~= nil and raw_route.deadline_seconds or (route_template and route_template.deadline_seconds)
    local raw_reward_skill_xp = raw_route ~= nil and raw_route.reward_skill_xp or (route_template and route_template.reward_skill_xp)
    local raw_required_skill_level = raw_route ~= nil and raw_route.required_skill_level or (route_template and route_template.required_skill_level)
    local raw_pickup_location_key = raw_route ~= nil and raw_route.pickup_location_key or (route_template and route_template.pickup_location_key)
    local raw_delivery_location_key = raw_route ~= nil and raw_route.delivery_location_key or (route_template and route_template.delivery_location_key)

    if normalize_route_key((raw_route and raw_route.key) or (route_template and route_template.key)) == nil then
        add_route_diagnostic_issue(result, "route-key-invalid")
    end

    if normalize_item_key((raw_route and raw_route.item_key) or (route_template and route_template.item_key)) == nil then
        add_route_diagnostic_issue(result, "item-missing")
    end

    if normalize_positive_integer(raw_item_quantity) == nil
        or (normalize_positive_integer(raw_item_quantity) or 0) > MAX_DELIVERY_QUANTITY
    then
        add_route_diagnostic_issue(result, "quantity-invalid")
    end

    if normalize_reward_money(raw_reward_money) == nil then
        add_route_diagnostic_issue(result, "reward-invalid")
    end

    if raw_deadline_seconds ~= nil and normalize_deadline_seconds(raw_deadline_seconds) == nil then
        add_route_diagnostic_issue(result, "deadline-invalid")
    end

    if raw_reward_skill_xp ~= nil and normalize_non_negative_integer(raw_reward_skill_xp) == nil then
        add_route_diagnostic_issue(result, "reward-xp-invalid")
    end

    if raw_required_skill_level ~= nil and normalize_required_skill_level(raw_required_skill_level) == nil then
        add_route_diagnostic_issue(result, "requirement-invalid")
    end

    if raw_route ~= nil and raw_route.required_reputation_min ~= nil and (normalized_required_reputation_min == nil or normalized_required_reputation_min < 0) then
        add_route_diagnostic_issue(result, "requirement-invalid")
    end

    if normalize_location_key(raw_pickup_location_key) == nil or pickup_location == nil then
        add_route_diagnostic_issue(result, "pickup-missing")
    else
        if pickup_location.is_active ~= true then
            add_route_diagnostic_issue(result, "pickup-inactive")
        end

        if not is_location_calibrated(pickup_location) then
            add_route_diagnostic_issue(result, "pickup-position-missing")
            result.is_uncalibrated = true
        end

        if not is_location_radius_valid(pickup_location) then
            add_route_diagnostic_issue(result, "pickup-radius-invalid")
        end
    end

    if normalize_location_key(raw_delivery_location_key) == nil or delivery_location == nil then
        add_route_diagnostic_issue(result, "delivery-missing")
    else
        if delivery_location.is_active ~= true then
            add_route_diagnostic_issue(result, "delivery-inactive")
        end

        if not is_location_calibrated(delivery_location) then
            add_route_diagnostic_issue(result, "delivery-position-missing")
            result.is_uncalibrated = true
        end

        if not is_location_radius_valid(delivery_location) then
            add_route_diagnostic_issue(result, "delivery-radius-invalid")
        end
    end

    result.is_valid = #result.issue_codes == 0
    result._issue_set = nil

    return result
end

function ContractService:ValidateRouteTemplate(route_key, callback)
    local normalized_route_key = normalize_route_key(route_key)

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if self.repository == nil then
        return callback_repository_missing(callback)
    end

    if normalized_route_key == nil then
        callback(false, nil, "route-not-found")
        return true
    end

    return self.repository:ListRouteTemplatesWithLocations(true, function(is_success, route_rows, error)
        if not is_success then
            callback(false, nil, error or "database-error")
            return
        end

        for _, route_row in ipairs(route_rows or {}) do
            local route_template = route_row and route_row.route or nil

            if normalize_route_key(route_template and route_template.key) == normalized_route_key then
                callback(
                    true,
                    self:EvaluateRouteTemplateHealth(
                        route_template,
                        route_row.pickup_location,
                        route_row.delivery_location,
                        route_row.raw_route
                    ),
                    nil
                )
                return
            end
        end

        callback(false, nil, "route-not-found")
    end)
end

function ContractService:IsRoutePlayable(route_key_or_route, callback)
    local route_template_argument = type(route_key_or_route) == "table" and route_key_or_route or nil
    local normalized_route_key = normalize_route_key(route_template_argument and route_template_argument.key or route_key_or_route)

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if self.repository == nil then
        return callback_repository_missing(callback)
    end

    if normalized_route_key == nil then
        callback(false, nil, "route-not-found")
        return true
    end

    return self:ValidateRouteTemplate(normalized_route_key, function(is_success, health_result, error)
        local route_template = route_template_argument

        if not is_success then
            callback(false, nil, error or "database-error")
            return
        end

        if type(health_result) ~= "table" or health_result.route == nil then
            callback(false, nil, "route-not-found")
            return
        end

        if route_template == nil then
            route_template = health_result.route
        else
            health_result.route = route_template
        end

        if route_template.is_active ~= true then
            health_result.is_playable = false
            callback(true, health_result, "route-inactive")
            return
        end

        if health_result.is_valid ~= true then
            health_result.is_playable = false
            callback(true, health_result, "route-unavailable")
            return
        end

        health_result.is_playable = true
        callback(true, health_result, nil)
    end)
end

function ContractService:FilterPlayableRoutes(route_templates, callback)
    local playable_routes = {}
    local index = 1

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if self.repository == nil then
        return callback_repository_missing(callback)
    end

    local function process_next()
        local route_template = route_templates and route_templates[index] or nil

        if route_template == nil then
            callback(true, playable_routes, nil)
            return
        end

        index = index + 1

        self:IsRoutePlayable(route_template, function(is_success, playability_result, error)
            if not is_success then
                callback(false, nil, error or "database-error")
                return
            end

            if playability_result ~= nil and playability_result.is_playable == true then
                playable_routes[#playable_routes + 1] = playability_result.route
            end

            process_next()
        end)
    end

    process_next()
end

function ContractService:GetRouteHealth(callback)
    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if self.repository == nil then
        return callback_repository_missing(callback)
    end

    return self.repository:ListRouteTemplatesWithLocations(true, function(is_success, route_rows, error)
        local summary = {
            total = 0,
            active = 0,
            inactive = 0,
            valid = 0,
            invalid = 0,
            uncalibrated = 0,
            issue_counts = {},
            rows = {},
        }
        local route_index = 1

        if not is_success then
            callback(false, nil, error or "database-error")
            return
        end

        summary.total = #(route_rows or {})

        local function process_next()
            local route_row = route_rows[route_index]
            local route_template = route_row and route_row.route or nil

            if route_template == nil then
                callback(true, summary, nil)
                return
            end

            local health_result = self:EvaluateRouteTemplateHealth(
                route_template,
                route_row and route_row.pickup_location or nil,
                route_row and route_row.delivery_location or nil,
                route_row and route_row.raw_route or nil
            )

            if route_template.is_active == true then
                summary.active = summary.active + 1
            else
                summary.inactive = summary.inactive + 1
            end

            if health_result.is_valid == true then
                summary.valid = summary.valid + 1
            else
                summary.invalid = summary.invalid + 1
            end

            if health_result.is_uncalibrated == true then
                summary.uncalibrated = summary.uncalibrated + 1
            end

            for _, issue_code in ipairs(health_result.issue_codes or {}) do
                summary.issue_counts[issue_code] = (summary.issue_counts[issue_code] or 0) + 1
            end

            summary.rows[#summary.rows + 1] = health_result
            route_index = route_index + 1
            process_next()
        end

        process_next()
    end)
end

function ContractService:ListInvalidRoutes(callback)
    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if self.repository == nil then
        return callback_repository_missing(callback)
    end

    return self:GetRouteHealth(function(is_success, summary, error)
        local invalid_rows = {}

        if not is_success then
            callback(false, nil, error or "database-error")
            return
        end

        for _, health_result in ipairs((summary and summary.rows) or {}) do
            if health_result.is_valid ~= true then
                invalid_rows[#invalid_rows + 1] = health_result
            end
        end

        callback(true, invalid_rows, nil)
    end)
end

function ContractService:GetContractLocationRoutes(location_key, callback)
    local normalized_location_key = normalize_location_key(location_key)

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if self.repository == nil then
        return callback_repository_missing(callback)
    end

    if normalized_location_key == nil then
        callback(false, nil, "invalid-location-key")
        return true
    end

    return self:GetDeliveryLocationInfo(normalized_location_key, function(is_location_success, delivery_location, location_error)
        if not is_location_success then
            callback(false, nil, location_error or "database-error")
            return
        end

        self.repository:ListRoutesUsingLocation(normalized_location_key, function(is_routes_success, route_rows, routes_error)
            if not is_routes_success then
                callback(false, nil, routes_error or "database-error")
                return
            end

            callback(true, {
                location = delivery_location,
                routes = route_rows or {},
            }, nil)
        end)
    end)
end

function ContractService:GetContractLocationHealth(location_key, callback)
    local normalized_location_key = normalize_location_key(location_key)

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if self.repository == nil then
        return callback_repository_missing(callback)
    end

    if normalized_location_key == nil then
        callback(false, nil, "invalid-location-key")
        return true
    end

    return self:GetContractLocationRoutes(normalized_location_key, function(is_success, location_routes_result, error)
        local delivery_location = nil
        local route_rows = nil
        local health_result = nil
        local issues = {}
        local impacted_routes = {}
        local routes_total = 0
        local routes_active = 0
        local routes_invalid = 0
        local is_calibrated = false
        local is_radius_valid = false
        local usage_issue_codes = nil

        if not is_success then
            callback(false, nil, error or "database-error")
            return
        end

        delivery_location = location_routes_result and location_routes_result.location or nil
        route_rows = location_routes_result and location_routes_result.routes or {}
        is_calibrated = is_location_calibrated(delivery_location)
        is_radius_valid = is_location_radius_valid(delivery_location)
        routes_total = #(route_rows or {})

        if delivery_location ~= nil and delivery_location.is_active ~= true then
            issues[#issues + 1] = "location inactive"
        end

        if not is_calibrated then
            issues[#issues + 1] = "position non calibree"
        end

        if not is_radius_valid then
            issues[#issues + 1] = "radius invalide"
        end

        for _, route_row in ipairs(route_rows or {}) do
            local route_template = route_row and route_row.route or nil
            local usage = trim_string(route_row and route_row.usage)
            local route_impacted = false

            if route_template ~= nil and route_template.is_active == true then
                routes_active = routes_active + 1
            end

            health_result = self:EvaluateRouteTemplateHealth(
                route_template,
                route_row and route_row.pickup_location or nil,
                route_row and route_row.delivery_location or nil,
                route_row and route_row.raw_route or nil
            )

            usage_issue_codes = {}

            if usage == "pickup" or usage == "pickup,destination" then
                usage_issue_codes[#usage_issue_codes + 1] = "pickup-missing"
                usage_issue_codes[#usage_issue_codes + 1] = "pickup-inactive"
                usage_issue_codes[#usage_issue_codes + 1] = "pickup-position-missing"
                usage_issue_codes[#usage_issue_codes + 1] = "pickup-radius-invalid"
            end

            if usage == "destination" or usage == "pickup,destination" then
                usage_issue_codes[#usage_issue_codes + 1] = "delivery-missing"
                usage_issue_codes[#usage_issue_codes + 1] = "delivery-inactive"
                usage_issue_codes[#usage_issue_codes + 1] = "delivery-position-missing"
                usage_issue_codes[#usage_issue_codes + 1] = "delivery-radius-invalid"
            end

            for _, issue_code in ipairs(usage_issue_codes) do
                if table_contains_value(health_result and health_result.issue_codes, issue_code) then
                    route_impacted = true
                    break
                end
            end

            if route_impacted then
                routes_invalid = routes_invalid + 1
                impacted_routes[#impacted_routes + 1] = {
                    route = route_template,
                    usage = usage,
                }
            end
        end

        callback(true, {
            location = delivery_location,
            status = #issues == 0 and "OK" or "WARNING",
            is_calibrated = is_calibrated,
            is_radius_valid = is_radius_valid,
            routes_total = routes_total,
            routes_active = routes_active,
            routes_invalid = routes_invalid,
            issues = issues,
            impacted_routes = impacted_routes,
        }, nil)
    end)
end

function ContractService:ListUnusedContractLocations(callback)
    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if self.repository == nil then
        return callback_repository_missing(callback)
    end

    return self.repository:ListUnusedContractLocations(function(is_success, delivery_locations, error)
        if not is_success then
            callback(false, nil, error or "database-error")
            return
        end

        callback(true, delivery_locations or {}, nil)
    end)
end

function ContractService:ListAllRouteTemplates(callback)
    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if self.repository == nil then
        return callback_repository_missing(callback)
    end

    return self.repository:ListAllRouteTemplates(callback)
end

function ContractService:SetRouteActive(route_key, is_active, callback)
    local normalized_route_key = normalize_route_key(route_key)
    local normalized_is_active = normalize_boolean_text(is_active)

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if self.repository == nil then
        return callback_repository_missing(callback)
    end

    if normalized_route_key == nil then
        callback(false, nil, "invalid-route-key")
        return true
    end

    if normalized_is_active == nil then
        callback(false, nil, "invalid-active-value")
        return true
    end

    if normalized_is_active == false then
        return self.repository:UpdateRouteActive(normalized_route_key, normalized_is_active, function(is_success, route_template, error)
            if not is_success then
                callback(false, nil, error or "database-error")
                return
            end

            if route_template == nil then
                callback(false, nil, "route-not-found")
                return
            end

            callback(true, route_template, nil)
        end)
    end

    return self:ValidateRouteTemplate(normalized_route_key, function(is_validate_success, health_result, validate_error)
        if not is_validate_success then
            callback(false, nil, validate_error or "database-error")
            return
        end

        if type(health_result) ~= "table" or health_result.route == nil then
            callback(false, nil, "route-not-found")
            return
        end

        if health_result.is_valid ~= true then
            callback(false, health_result, "route-invalid")
            return
        end

        self.repository:UpdateRouteActive(normalized_route_key, true, function(is_success, route_template, error)
            if not is_success then
                callback(false, nil, error or "database-error")
                return
            end

            if route_template == nil then
                callback(false, nil, "route-not-found")
                return
            end

            callback(true, route_template, nil)
        end)
    end)
end

function ContractService:ForceSetRouteActive(route_key, is_active, callback)
    local normalized_route_key = normalize_route_key(route_key)
    local normalized_is_active = normalize_boolean_text(is_active)

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if self.repository == nil then
        return callback_repository_missing(callback)
    end

    if normalized_route_key == nil then
        callback(false, nil, "invalid-route-key")
        return true
    end

    if normalized_is_active == nil then
        callback(false, nil, "invalid-active-value")
        return true
    end

    return self.repository:UpdateRouteActive(normalized_route_key, normalized_is_active, function(is_success, route_template, error)
        if not is_success then
            callback(false, nil, error or "database-error")
            return
        end

        if route_template == nil then
            callback(false, nil, "route-not-found")
            return
        end

        callback(true, route_template, nil)
    end)
end

function ContractService:SetRouteDeadline(route_key, deadline_seconds, callback)
    local normalized_route_key = normalize_route_key(route_key)
    local normalized_deadline_seconds = nil
    local deadline_value = trim_string(deadline_seconds)

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if self.repository == nil then
        return callback_repository_missing(callback)
    end

    if normalized_route_key == nil then
        callback(false, nil, "invalid-route-key")
        return true
    end

    if deadline_value ~= nil and string.lower(deadline_value) ~= "none" then
        normalized_deadline_seconds = normalize_deadline_seconds(deadline_seconds)

        if normalized_deadline_seconds == nil then
            callback(false, nil, "invalid-deadline")
            return true
        end
    elseif deadline_value == nil and deadline_seconds ~= nil then
        callback(false, nil, "invalid-deadline")
        return true
    end

    return self.repository:UpdateRouteDeadline(normalized_route_key, normalized_deadline_seconds, function(is_success, route_template, error)
        if not is_success then
            callback(false, nil, error or "database-error")
            return
        end

        if route_template == nil then
            callback(false, nil, "route-not-found")
            return
        end

        callback(true, route_template, nil)
    end)
end

function ContractService:SetRouteReward(route_key, reward_money, reward_skill_xp, callback)
    local normalized_route_key = normalize_route_key(route_key)
    local normalized_reward_money = normalize_reward_money(reward_money)
    local normalized_reward_skill_xp = nil

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if self.repository == nil then
        return callback_repository_missing(callback)
    end

    if normalized_route_key == nil then
        callback(false, nil, "invalid-route-key")
        return true
    end

    if normalized_reward_money == nil then
        callback(false, nil, "invalid-reward")
        return true
    end

    if reward_skill_xp ~= nil then
        normalized_reward_skill_xp = normalize_non_negative_integer(reward_skill_xp)

        if normalized_reward_skill_xp == nil then
            callback(false, nil, "invalid-reward")
            return true
        end
    end

    return self:GetRouteTemplate(normalized_route_key, function(is_get_success, route_template, get_error)
        local effective_reward_skill_xp = normalized_reward_skill_xp

        if not is_get_success then
            callback(false, nil, get_error or "database-error")
            return
        end

        if route_template == nil then
            callback(false, nil, "route-not-found")
            return
        end

        if effective_reward_skill_xp == nil then
            effective_reward_skill_xp = normalize_non_negative_integer(route_template.reward_skill_xp) or 0
        end

        self.repository:UpdateRouteReward(normalized_route_key, normalized_reward_money, effective_reward_skill_xp, function(is_update_success, updated_route_template, update_error)
            if not is_update_success then
                callback(false, nil, update_error or "database-error")
                return
            end

            if updated_route_template == nil then
                callback(false, nil, "route-not-found")
                return
            end

            callback(true, updated_route_template, nil)
        end)
    end)
end

function ContractService:SetRouteRequirement(route_key, required_skill_key, required_skill_level, callback)
    local normalized_route_key = normalize_route_key(route_key)
    local skill_key_value = trim_string(required_skill_key)
    local normalized_required_skill_key = nil
    local normalized_required_skill_level = nil

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if self.repository == nil then
        return callback_repository_missing(callback)
    end

    if normalized_route_key == nil then
        callback(false, nil, "invalid-route-key")
        return true
    end

    if skill_key_value ~= nil and string.lower(skill_key_value) ~= "none" then
        normalized_required_skill_key = normalize_required_skill_key(skill_key_value)
        normalized_required_skill_level = normalize_required_skill_level(required_skill_level)

        if normalized_required_skill_key == nil or normalized_required_skill_level == nil or normalized_required_skill_level < 1 then
            callback(false, nil, "invalid-requirement")
            return true
        end
    else
        normalized_required_skill_key = nil
        normalized_required_skill_level = normalize_required_skill_level(required_skill_level)

        if normalized_required_skill_level == nil or normalized_required_skill_level ~= 0 then
            callback(false, nil, "invalid-requirement")
            return true
        end
    end

    return self.repository:UpdateRouteRequirement(
        normalized_route_key,
        normalized_required_skill_key,
        normalized_required_skill_level,
        function(is_success, route_template, error)
            if not is_success then
                callback(false, nil, error or "database-error")
                return
            end

            if route_template == nil then
                callback(false, nil, "route-not-found")
                return
            end

            callback(true, route_template, nil)
        end
    )
end

function ContractService:ListJobBoardRoutes(callback)
    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    return self:ListRouteTemplates(function(is_success, route_templates, error)
        if not is_success then
            callback(false, nil, error or "database-error")
            return
        end

        self:FilterPlayableRoutes(route_templates, callback)
    end)
end

function ContractService:GetJobBoardRoute(route_key, callback)
    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    return self:GetRouteTemplate(route_key, callback)
end

function ContractService:TakeJobFromRoute(character_id, route_key, callback)
    local normalized_character_id = normalize_positive_integer(character_id)
    local normalized_route_key = normalize_route_key(route_key)

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if self.repository == nil then
        return callback_repository_missing(callback)
    end

    if normalized_character_id == nil then
        callback(false, nil, "invalid-character")
        return true
    end

    if normalized_route_key == nil then
        callback(false, nil, "route-not-found")
        return true
    end

    return self:ExpireContracts(function(is_expire_success, _, expire_error)
        if not is_expire_success then
            callback(false, nil, expire_error or "database-error")
            return
        end

        self.repository:ListContractsForCharacter(normalized_character_id, function(is_list_success, contract_rows, list_error)
            local active_job_count = 0

            if not is_list_success then
                callback(false, nil, list_error or "database-error")
                return
            end

            for _, contract_row in ipairs(contract_rows or {}) do
                if is_active_job_contract(contract_row, normalized_character_id) then
                    active_job_count = active_job_count + 1
                end
            end

            if active_job_count >= MAX_ACTIVE_JOB_CONTRACTS then
                callback(false, nil, "active-job-limit-reached")
                return
            end

            self:GetRouteTemplate(normalized_route_key, function(is_route_success, route_template, route_error)
                if not is_route_success then
                    callback(false, nil, route_error or "database-error")
                    return
                end

                if route_template == nil then
                    callback(false, nil, "route-not-found")
                    return
                end

                if route_template.is_active ~= true then
                    callback(false, route_template, "route-inactive")
                    return
                end

                self:IsRoutePlayable(route_template, function(is_playable_success, playability_result, playability_error)
                    if not is_playable_success then
                        callback(false, nil, playability_error or "database-error")
                        return
                    end

                    if playability_result == nil or playability_result.is_playable ~= true then
                        callback(false, playability_result, playability_error or "route-unavailable")
                        return
                    end

                    self:CheckJobRequirements(normalized_character_id, route_template, function(is_requirements_success, requirements_result, requirements_error)
                        if not is_requirements_success then
                            callback(false, requirements_result or route_template, requirements_error or "requirements-not-met")
                            return
                        end

                        self:CreateHaulContract(
                            normalized_character_id,
                            route_template.item_key,
                            route_template.item_quantity,
                            route_template.reward_money,
                            route_template.pickup_location_key,
                            route_template.delivery_location_key,
                            build_route_contract_description(route_template),
                            {
                                source_route_key = route_template.key,
                                job_source = "job_board",
                                deadline_seconds = route_template.deadline_seconds,
                                reward_skill_key = route_template.reward_skill_key,
                                reward_skill_xp = route_template.reward_skill_xp,
                                reward_reputation_key = route_template.reward_reputation_key,
                                reward_reputation_delta = route_template.reward_reputation_delta,
                            },
                            function(is_create_success, contract_row, create_error)
                                if not is_create_success then
                                    callback(false, route_template, create_error or "contract-create-failed")
                                    return
                                end

                                if contract_row == nil or normalize_positive_integer(contract_row.id) == nil then
                                    callback(false, route_template, "contract-create-failed")
                                    return
                                end

                                self.repository:AcceptContract(contract_row.id, normalized_character_id, function(is_accept_success, accepted_row, accept_error)
                                    if not is_accept_success or accepted_row == nil then
                                        self.repository:CancelContract(contract_row.id, normalized_character_id, function()
                                            callback(false, contract_row, "contract-assign-failed")
                                        end)
                                        return
                                    end

                                    accepted_row.route_key = route_template.key
                                    accepted_row.route_name = route_template.name

                                    callback(true, accepted_row, nil)
                                end)
                            end
                        )
                    end)
                end)
            end)
        end)
    end)
end

function ContractService:GetDeliveryLocation(location_key, callback)
    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if self.repository == nil then
        return callback_repository_missing(callback)
    end

    return self.repository:GetDeliveryLocation(location_key, callback)
end

function ContractService:GetDeliveryLocationInfo(location_key, callback)
    local normalized_location_key = normalize_location_key(location_key)

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if self.repository == nil then
        return callback_repository_missing(callback)
    end

    if normalized_location_key == nil then
        callback(false, nil, "location-not-found")
        return true
    end

    return self.repository:GetDeliveryLocation(normalized_location_key, function(is_success, delivery_location, error)
        if not is_success then
            callback(false, nil, error or "database-error")
            return
        end

        if delivery_location == nil then
            callback(false, nil, "location-not-found")
            return
        end

        callback(true, delivery_location, nil)
    end)
end

function ContractService:CreateContractLocation(location_key, radius, name, callback)
    local normalized_location_key = normalize_location_key(location_key)
    local normalized_radius = normalize_positive_integer(radius)
    local normalized_name = normalize_location_name(name)

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if self.repository == nil then
        return callback_repository_missing(callback)
    end

    if normalized_location_key == nil then
        callback(false, nil, "invalid-location-key")
        return true
    end

    if normalized_radius == nil or normalized_radius > MAX_CONTRACT_LOCATION_RADIUS then
        callback(false, nil, "invalid-radius")
        return true
    end

    if normalized_name == nil then
        callback(false, nil, "invalid-name")
        return true
    end

    return self.repository:GetDeliveryLocation(normalized_location_key, function(is_get_success, delivery_location, get_error)
        if not is_get_success then
            callback(false, nil, get_error or "database-error")
            return
        end

        if delivery_location ~= nil then
            callback(false, delivery_location, "location-already-exists")
            return
        end

        self.repository:CreateContractLocation({
            key = normalized_location_key,
            name = normalized_name,
            description = "",
            radius = normalized_radius,
        }, function(is_create_success, created_location, create_error)
            if not is_create_success then
                callback(false, nil, create_error or "database-error")
                return
            end

            if created_location == nil then
                callback(false, nil, "database-error")
                return
            end

            callback(true, created_location, nil)
        end)
    end)
end

function ContractService:SetContractLocationActive(location_key, is_active, callback)
    local normalized_location_key = normalize_location_key(location_key)
    local normalized_is_active = normalize_boolean_text(is_active)

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if self.repository == nil then
        return callback_repository_missing(callback)
    end

    if normalized_location_key == nil then
        callback(false, nil, "invalid-location-key")
        return true
    end

    if normalized_is_active == nil then
        callback(false, nil, "invalid-active-value")
        return true
    end

    return self.repository:UpdateContractLocationActive(normalized_location_key, normalized_is_active, function(is_success, delivery_location, error)
        if not is_success then
            callback(false, nil, error or "database-error")
            return
        end

        if delivery_location == nil then
            callback(false, nil, "location-not-found")
            return
        end

        callback(true, delivery_location, nil)
    end)
end

function ContractService:SetContractLocationRadius(location_key, radius, callback)
    local normalized_location_key = normalize_location_key(location_key)
    local normalized_radius = normalize_positive_integer(radius)

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if self.repository == nil then
        return callback_repository_missing(callback)
    end

    if normalized_location_key == nil then
        callback(false, nil, "invalid-location-key")
        return true
    end

    if normalized_radius == nil or normalized_radius > MAX_CONTRACT_LOCATION_RADIUS then
        callback(false, nil, "invalid-radius")
        return true
    end

    return self.repository:UpdateContractLocationRadius(normalized_location_key, normalized_radius, function(is_success, delivery_location, error)
        if not is_success then
            callback(false, nil, error or "database-error")
            return
        end

        if delivery_location == nil then
            callback(false, nil, "location-not-found")
            return
        end

        callback(true, delivery_location, nil)
    end)
end

function ContractService:SetContractLocationName(location_key, name, callback)
    local normalized_location_key = normalize_location_key(location_key)
    local normalized_name = normalize_location_name(name)

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if self.repository == nil then
        return callback_repository_missing(callback)
    end

    if normalized_location_key == nil then
        callback(false, nil, "invalid-location-key")
        return true
    end

    if normalized_name == nil then
        callback(false, nil, "invalid-name")
        return true
    end

    return self.repository:UpdateContractLocationName(normalized_location_key, normalized_name, function(is_success, delivery_location, error)
        if not is_success then
            callback(false, nil, error or "database-error")
            return
        end

        if delivery_location == nil then
            callback(false, nil, "location-not-found")
            return
        end

        callback(true, delivery_location, nil)
    end)
end

function ContractService:SetDeliveryLocationHere(player, location_key, radius, callback)
    local normalized_location_key = normalize_location_key(location_key)
    local normalized_radius = nil

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if self.repository == nil then
        return callback_repository_missing(callback)
    end

    if normalized_location_key == nil then
        callback(false, nil, "location-not-found")
        return true
    end

    if radius ~= nil then
        normalized_radius = normalize_number(radius)

        if normalized_radius == nil or normalized_radius <= 0 or normalized_radius > MAX_DELIVERY_LOCATION_RADIUS then
            callback(false, nil, "invalid-radius")
            return true
        end
    end

    local controlled_character = get_controlled_character(player)

    if controlled_character == nil then
        callback(false, nil, "player-position-unavailable")
        return true
    end

    local player_location = get_entity_location(controlled_character)

    if player_location == nil then
        callback(false, nil, "player-position-unavailable")
        return true
    end

    return self.repository:GetDeliveryLocation(normalized_location_key, function(is_get_success, delivery_location, get_error)
        local effective_radius = normalized_radius

        if not is_get_success then
            callback(false, nil, get_error or "database-error")
            return
        end

        if delivery_location == nil then
            callback(false, nil, "location-not-found")
            return
        end

        if delivery_location.is_active ~= true then
            callback(false, nil, "location-inactive")
            return
        end

        if effective_radius == nil then
            effective_radius = normalize_number(delivery_location.radius) or DEFAULT_DELIVERY_LOCATION_RADIUS
        end

        if effective_radius <= 0 or effective_radius > MAX_DELIVERY_LOCATION_RADIUS then
            callback(false, nil, "invalid-radius")
            return
        end

        self.repository:UpdateDeliveryLocationPosition(
            normalized_location_key,
            player_location.x,
            player_location.y,
            player_location.z,
            effective_radius,
            function(is_update_success, updated_delivery_location, update_error)
                if not is_update_success then
                    callback(false, nil, update_error or "database-error")
                    return
                end

                if updated_delivery_location == nil then
                    callback(false, nil, "database-error")
                    return
                end

                callback(true, updated_delivery_location, nil)
            end
        )
    end)
end

function ContractService:ListOpenContracts(callback)
    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if self.repository == nil then
        return callback_repository_missing(callback)
    end

    return self.repository:ListOpenContracts(callback)
end

function ContractService:ListMyContracts(player_or_character_id, callback)
    local normalized_character_id = resolve_active_character_id(player_or_character_id)

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if self.repository == nil then
        return callback_repository_missing(callback)
    end

    if normalized_character_id == nil then
        callback(false, nil, "no-active-character")
        return true
    end

    return self.repository:ListActiveContractsByCharacter(normalized_character_id, function(is_success, contract_rows, error)
        local results = {}

        if not is_success then
            callback(false, nil, error)
            return
        end

        for _, contract_row in ipairs(contract_rows or {}) do
            local enriched_row = enrich_player_active_contract(contract_row)

            if enriched_row ~= nil then
                enriched_row.role = resolve_contract_role(contract_row, normalized_character_id)
                results[#results + 1] = enriched_row
            end
        end

        callback(true, results, nil)
    end)
end

function ContractService:GetMyContractStatus(player_or_character_id, contract_id, callback)
    local normalized_character_id = resolve_active_character_id(player_or_character_id)
    local normalized_contract_id = normalize_contract_id(contract_id)

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if self.repository == nil then
        return callback_repository_missing(callback)
    end

    if normalized_character_id == nil then
        callback(false, nil, "no-active-character")
        return true
    end

    if normalized_contract_id == nil then
        callback(false, nil, "invalid-contract-id")
        return true
    end

    return self.repository:GetContractByIdForCharacter(normalized_contract_id, normalized_character_id, function(is_success, contract_row, error)
        if not is_success then
            callback(false, nil, error or "database-error")
            return
        end

        if contract_row == nil then
            callback(false, nil, "contract-not-found")
            return
        end

        callback(true, enrich_player_active_contract(contract_row), nil)
    end)
end

function ContractService:AcceptContract(character_id, contract_id, callback)
    local normalized_character_id = normalize_positive_integer(character_id)
    local normalized_contract_id = normalize_contract_id(contract_id)

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if self.repository == nil then
        return callback_repository_missing(callback)
    end

    if normalized_character_id == nil then
        callback(false, nil, "character-id-required")
        return true
    end

    if normalized_contract_id == nil then
        callback(false, nil, "contract-id-invalid")
        return true
    end

    return self.repository:GetContractById(normalized_contract_id, function(is_get_success, contract_row, get_error)
        if not is_get_success then
            callback(false, nil, get_error)
            return
        end

        if contract_row == nil then
            callback(false, nil, "contract-not-found")
            return
        end

        self:EnsureContractNotExpired(contract_row, function(is_deadline_success, resolved_row, is_expired, deadline_error)
            if not is_deadline_success then
                callback(false, nil, deadline_error or "database-error")
                return
            end

            if is_expired then
                callback(false, resolved_row or contract_row, "contract-expired")
                return
            end

            contract_row = resolved_row or contract_row

            if contract_row.status ~= "open" then
                callback(false, nil, "contract-not-available")
                return
            end

            self.repository:AcceptContract(normalized_contract_id, normalized_character_id, function(is_accept_success, accepted_row, accept_error)
                if not is_accept_success then
                    callback(false, nil, accept_error)
                    return
                end

                if accepted_row == nil then
                    callback(false, nil, "contract-not-available")
                    return
                end

                Console.Log(
                    "[gr_contracts][service] Contract accepted id=%s assignee_character_id=%s.",
                    tostring(accepted_row.id),
                    tostring(normalized_character_id)
                )

                callback(true, accepted_row, nil)
            end)
        end)
    end)
end

function ContractService:ValidateDeliveryLocationProximity(player, delivery_location)
    if type(delivery_location) ~= "table" then
        return false, "delivery-location-not-found"
    end

    if delivery_location.is_active ~= true then
        return false, "delivery-location-inactive"
    end

    local position_x = normalize_number(delivery_location.position_x)
    local position_y = normalize_number(delivery_location.position_y)
    local position_z = normalize_number(delivery_location.position_z)
    local radius = normalize_number(delivery_location.radius)

    if position_x == nil or position_y == nil or position_z == nil or radius == nil or radius <= 0 then
        return false, "delivery-location-position-missing"
    end

    local controlled_character = get_controlled_character(player)

    if controlled_character == nil then
        return false, "player-position-unavailable"
    end

    local player_location = get_entity_location(controlled_character)

    if player_location == nil then
        return false, "player-position-unavailable"
    end

    local distance_squared = get_distance_squared(player_location, {
        x = position_x,
        y = position_y,
        z = position_z,
    })

    if distance_squared == nil then
        return false, "player-position-unavailable"
    end

    if distance_squared > (radius * radius) then
        return false, "too-far-from-delivery-location"
    end

    return true, nil
end

function ContractService:PickupContract(character_id, player, contract_id, callback)
    local normalized_character_id = normalize_positive_integer(character_id)
    local normalized_contract_id = normalize_contract_id(contract_id)

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if self.repository == nil then
        return callback_repository_missing(callback)
    end

    if normalized_character_id == nil then
        callback(false, nil, "character-id-required")
        return true
    end

    if normalized_contract_id == nil then
        callback(false, nil, "contract-id-invalid")
        return true
    end

    return self.repository:GetContractById(normalized_contract_id, function(is_get_success, contract_row, get_error)
        if not is_get_success then
            callback(false, nil, get_error)
            return
        end

        if contract_row == nil then
            callback(false, nil, "contract-not-found")
            return
        end

        self:EnsureContractNotExpired(contract_row, function(is_deadline_success, resolved_row, is_expired, deadline_error)
            if not is_deadline_success then
                callback(false, nil, deadline_error or "database-error")
                return
            end

            if is_expired then
                callback(false, resolved_row or contract_row, "contract-expired")
                return
            end

            contract_row = resolved_row or contract_row

            if contract_row.status ~= "accepted"
                or normalize_positive_integer(contract_row.assignee_character_id) ~= normalized_character_id
            then
                callback(false, contract_row, "pickup-contract-forbidden")
                return
            end

            if contract_row.requires_pickup_location ~= true then
                callback(false, contract_row, "pickup-not-required")
                return
            end

            local pickup_status = normalize_pickup_status(contract_row.pickup_status)

            if pickup_status ~= "pending" then
                callback(false, contract_row, "pickup-already-completed")
                return
            end

            local pickup_location_key = normalize_location_key(contract_row.pickup_location_key)
            local required_item_key = normalize_item_key(contract_row.required_item_key)
            local required_item_quantity = normalize_positive_integer(contract_row.required_item_quantity)
            local inventory_bridge = resolve_inventory_bridge()

            if pickup_location_key == nil then
                callback(false, contract_row, "pickup-location-not-found")
                return
            end

            if required_item_key == nil or required_item_quantity == nil then
                callback(false, contract_row, "pickup-item-invalid")
                return
            end

            if inventory_bridge == nil then
                callback(false, contract_row, "inventory-unavailable")
                return
            end

            self.repository:GetDeliveryLocation(pickup_location_key, function(is_location_success, pickup_location, location_error)
                if not is_location_success then
                    callback(false, contract_row, location_error or "pickup-location-not-found")
                    return
                end

                if pickup_location == nil then
                    callback(false, contract_row, "pickup-location-not-found")
                    return
                end

                local is_near_pickup, proximity_error = self:ValidateDeliveryLocationProximity(player, pickup_location)

                if not is_near_pickup then
                    if proximity_error == "delivery-location-not-found" then
                        callback(false, contract_row, "pickup-location-not-found")
                        return
                    end

                    if proximity_error == "delivery-location-inactive" then
                        callback(false, contract_row, "pickup-location-inactive")
                        return
                    end

                    if proximity_error == "delivery-location-position-missing" then
                        callback(false, contract_row, "pickup-location-position-missing")
                        return
                    end

                    if proximity_error == "too-far-from-delivery-location" then
                        callback(false, contract_row, "too-far-from-pickup-location")
                        return
                    end

                    callback(false, contract_row, proximity_error)
                    return
                end

                inventory_bridge.AddItem(normalized_character_id, required_item_key, required_item_quantity, {
                    source = "contract_pickup",
                    contract_id = normalized_contract_id,
                    pickup_location_key = pickup_location_key,
                }, function(is_add_success, _, add_error)
                    if not is_add_success then
                        Console.Log(
                            "[gr_contracts][service] Contract pickup add item failed contract_id=%s assignee_character_id=%s item_key=%s quantity=%s reason=%s.",
                            tostring(normalized_contract_id),
                            tostring(normalized_character_id),
                            tostring(required_item_key),
                            tostring(required_item_quantity),
                            tostring(add_error or "inventory-add-failed")
                        )
                        callback(false, contract_row, "inventory-unavailable")
                        return
                    end

                    self.repository:MarkContractPickedUp(normalized_contract_id, function(is_mark_success, picked_up_row, mark_error)
                        if not is_mark_success then
                            inventory_bridge.RemoveItem(normalized_character_id, required_item_key, required_item_quantity, function(is_remove_success)
                                if not is_remove_success then
                                    callback(false, contract_row, "inventory-compensation-failed")
                                    return
                                end

                                callback(false, contract_row, mark_error or "database-error")
                            end)
                            return
                        end

                        if picked_up_row == nil then
                            inventory_bridge.RemoveItem(normalized_character_id, required_item_key, required_item_quantity, function(is_remove_success)
                                if not is_remove_success then
                                    callback(false, contract_row, "inventory-compensation-failed")
                                    return
                                end

                                callback(false, contract_row, "pickup-already-completed")
                            end)
                            return
                        end

                        Console.Log(
                            "[gr_contracts][service] Contract cargo picked up id=%s assignee_character_id=%s pickup=%s item=%s quantity=%s.",
                            tostring(picked_up_row.id),
                            tostring(normalized_character_id),
                            tostring(pickup_location_key),
                            tostring(required_item_key),
                            tostring(required_item_quantity)
                        )

                        callback(true, picked_up_row, nil)
                    end)
                end)
            end)
        end)
    end)
end

function ContractService:CompleteContract(character_id, contract_id, player_or_callback, callback)
    local normalized_character_id = normalize_positive_integer(character_id)
    local normalized_contract_id = normalize_contract_id(contract_id)
    local player = player_or_callback

    if type(player_or_callback) == "function" and callback == nil then
        callback = player_or_callback
        player = nil
    end

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if self.repository == nil then
        return callback_repository_missing(callback)
    end

    if normalized_character_id == nil then
        callback(false, nil, "character-id-required")
        return true
    end

    if normalized_contract_id == nil then
        callback(false, nil, "contract-id-invalid")
        return true
    end

    return self.repository:GetContractById(normalized_contract_id, function(is_get_success, contract_row, get_error)
        if not is_get_success then
            callback(false, nil, get_error)
            return
        end

        if contract_row == nil then
            callback(false, nil, "contract-not-found")
            return
        end

        if contract_row.status == "completed" then
            if normalize_payment_status(contract_row.payment_status) == "paid" then
                Console.Log(
                    "[gr_contracts][service] Contract payment skipped reason=already-paid contract_id=%s.",
                    tostring(normalized_contract_id)
                )
            end

            callback(false, nil, "contract-already-completed")
            return
        end

        self:EnsureContractNotExpired(contract_row, function(is_deadline_success, resolved_row, is_expired, deadline_error)
            if not is_deadline_success then
                callback(false, nil, deadline_error or "database-error")
                return
            end

            if is_expired then
                callback(false, resolved_row or contract_row, "contract-expired")
                return
            end

            contract_row = resolved_row or contract_row

            if contract_row.status ~= "accepted"
                or normalize_positive_integer(contract_row.assignee_character_id) ~= normalized_character_id
            then
                callback(false, nil, "contract-complete-forbidden")
                return
            end

            local required_item_key = normalize_item_key(contract_row.required_item_key)
            local required_item_quantity = normalize_positive_integer(contract_row.required_item_quantity)
            local should_consume_required_items = contract_row.consume_required_items ~= false
            local inventory_bridge = nil
            local requires_pickup_location = contract_row.requires_pickup_location == true
            local pickup_status = normalize_pickup_status(contract_row.pickup_status)
            local delivery_location_key = normalize_location_key(contract_row.delivery_location_key)
            local requires_delivery_location = contract_row.requires_delivery_location == true

            if requires_pickup_location and pickup_status ~= "picked_up" then
                callback(false, contract_row, "pickup-not-completed")
                return
            end

            local function continue_after_requirements()
            self.repository:CompleteContract(normalized_contract_id, normalized_character_id, function(is_complete_success, completed_row, complete_error)
                if not is_complete_success then
                    if required_item_key ~= nil and required_item_quantity ~= nil and should_consume_required_items and inventory_bridge ~= nil then
                        inventory_bridge.AddItem(normalized_character_id, required_item_key, required_item_quantity, nil, function(is_compensation_success)
                            if not is_compensation_success then
                                callback(false, contract_row, "inventory-compensation-failed")
                                return
                            end

                            callback(false, contract_row, complete_error or "contract-complete-failed")
                        end)
                        return
                    end

                    callback(false, nil, complete_error)
                    return
                end

                if completed_row == nil then
                    if required_item_key ~= nil and required_item_quantity ~= nil and should_consume_required_items and inventory_bridge ~= nil then
                        inventory_bridge.AddItem(normalized_character_id, required_item_key, required_item_quantity, nil, function(is_compensation_success)
                            if not is_compensation_success then
                                callback(false, contract_row, "inventory-compensation-failed")
                                return
                            end

                            callback(false, contract_row, "contract-complete-forbidden")
                        end)
                        return
                    end

                    callback(false, nil, "contract-complete-forbidden")
                    return
                end

                local reward_money = normalize_reward_money(completed_row.reward_money) or 0

                local function finish_success(payment_status, money_result)
                    local enriched_row = {}

                    for key, value in pairs(completed_row) do
                        enriched_row[key] = value
                    end

                    enriched_row.payment_status = payment_status
                    enriched_row.money_result = money_result

                    Console.Log(
                        "[gr_contracts][service] Contract completed id=%s assignee_character_id=%s.",
                        tostring(enriched_row.id),
                        tostring(normalized_character_id)
                    )

                    self:GrantContractRewards(enriched_row.id, function(is_rewards_success, reward_row, rewards_error)
                        local final_row = reward_row or enriched_row

                        if final_row ~= enriched_row then
                            final_row.money_result = money_result
                            final_row.payment_status = final_row.payment_status or payment_status
                        end

                        if not is_rewards_success and rewards_error ~= "rewards-not-required" and rewards_error ~= "rewards-already-granted" then
                            Console.Log(
                                "[gr_contracts][service] Contract rewards failed contract_id=%s assignee_character_id=%s reason=%s.",
                                tostring(enriched_row.id),
                                tostring(normalized_character_id),
                                tostring(rewards_error)
                            )
                        end

                        callback(true, final_row, nil)
                    end)
                end

                local function mark_payment_and_finish(payment_status, money_result)
                    self.repository:MarkContractPayment(normalized_contract_id, payment_status, function(is_mark_success, marked_row, mark_error)
                        if not is_mark_success then
                            Console.Log(
                                "[gr_contracts][service] Contract payment tracking failed contract_id=%s payment_status=%s reason=%s.",
                                tostring(normalized_contract_id),
                                tostring(payment_status),
                                tostring(mark_error)
                            )
                            finish_success(payment_status, money_result)
                            return
                        end

                        if marked_row ~= nil then
                            completed_row = marked_row
                        end

                        finish_success(payment_status, money_result)
                    end)
                end

                local function fail_with_payment_compensation(error_code)
                    if required_item_key == nil or required_item_quantity == nil or not should_consume_required_items or inventory_bridge == nil then
                        callback(false, completed_row, error_code)
                        return
                    end

                    inventory_bridge.AddItem(normalized_character_id, required_item_key, required_item_quantity, nil, function(is_compensation_success)
                        if not is_compensation_success then
                            Console.Log(
                                "[gr_contracts][service] Contract item compensation failed contract_id=%s assignee_character_id=%s item_key=%s quantity=%s.",
                                tostring(normalized_contract_id),
                                tostring(normalized_character_id),
                                tostring(required_item_key),
                                tostring(required_item_quantity)
                            )
                            callback(false, completed_row, "inventory-compensation-failed")
                            return
                        end

                        callback(false, completed_row, error_code)
                    end)
                end

                if reward_money <= 0 then
                    Console.Log(
                        "[gr_contracts][service] Contract payment unavailable reason=%s contract_id=%s.",
                        "reward-money-non-positive",
                        tostring(normalized_contract_id)
                    )
                    mark_payment_and_finish("unavailable", {
                        money_bank = nil,
                        amount = reward_money,
                    })
                    return
                end

                local economy_bridge = resolve_economy_bridge()

                if economy_bridge == nil then
                    Console.Log(
                        "[gr_contracts][service] Contract payment failed reason=%s contract_id=%s.",
                        "economy-bridge-unavailable",
                        tostring(normalized_contract_id)
                    )
                    self.repository:MarkContractPayment(normalized_contract_id, "failed", function()
                        fail_with_payment_compensation("payment-failed")
                    end)
                    return
                end

                local payment_reason = string.format("contract:%s", tostring(normalized_contract_id))
                local payment_metadata = {
                    contract_id = normalized_contract_id,
                    contract_type = completed_row.type,
                    source = "gr-contracts",
                    required_item_key = required_item_key,
                    required_item_quantity = required_item_quantity,
                }

                Console.Log(
                    "[gr_contracts][service] Contract payment requested through economy contract_id=%s assignee_character_id=%s amount=%s.",
                    tostring(normalized_contract_id),
                    tostring(normalized_character_id),
                    tostring(reward_money)
                )

                economy_bridge.AddMoney(
                    normalized_character_id,
                    "bank",
                    reward_money,
                    payment_reason,
                    payment_metadata,
                    function(is_credit_success, money_result, credit_error)
                        if not is_credit_success or money_result == nil then
                            Console.Log(
                                "[gr_contracts][service] Contract payment failed through economy contract_id=%s assignee_character_id=%s amount=%s reason=%s.",
                                tostring(normalized_contract_id),
                                tostring(normalized_character_id),
                                tostring(reward_money),
                                tostring(credit_error or "economy-credit-failed")
                            )

                            self.repository:MarkContractPayment(normalized_contract_id, "failed", function()
                                fail_with_payment_compensation("payment-failed")
                            end)
                            return
                        end

                        Console.Log(
                            "[gr_contracts][service] Contract payment completed through economy contract_id=%s assignee_character_id=%s amount=%s.",
                            tostring(normalized_contract_id),
                            tostring(normalized_character_id),
                            tostring(reward_money)
                        )

                        mark_payment_and_finish("paid", {
                            balance = money_result.balance,
                            transaction = money_result.transaction,
                            amount = reward_money,
                        })
                    end
                )
            end)
        end

            local function continue_after_delivery_location()
            if required_item_key == nil or required_item_quantity == nil or required_item_quantity < 1 or not should_consume_required_items then
                continue_after_requirements()
                return
            end

            inventory_bridge = resolve_inventory_bridge()

            if inventory_bridge == nil then
                callback(false, contract_row, "inventory-check-unavailable")
                return
            end

            inventory_bridge.ListInventory(normalized_character_id, function(is_list_success, inventory_rows, list_error)
                if not is_list_success then
                    Console.Log(
                        "[gr_contracts][service] Contract inventory check failed contract_id=%s assignee_character_id=%s reason=%s.",
                        tostring(normalized_contract_id),
                        tostring(normalized_character_id),
                        tostring(list_error or "inventory-list-failed")
                    )
                    callback(false, contract_row, "inventory-check-unavailable")
                    return
                end

                local has_items, available_quantity = has_required_items(inventory_rows, required_item_key, required_item_quantity)

                if not has_items then
                    local error_row = {}

                    for key, value in pairs(contract_row) do
                        error_row[key] = value
                    end

                    error_row.available_item_quantity = available_quantity
                    callback(false, error_row, "required-item-missing")
                    return
                end

                inventory_bridge.RemoveItem(normalized_character_id, required_item_key, required_item_quantity, function(is_remove_success, _, remove_error)
                    if not is_remove_success then
                        Console.Log(
                            "[gr_contracts][service] Contract inventory remove failed contract_id=%s assignee_character_id=%s item_key=%s quantity=%s reason=%s.",
                            tostring(normalized_contract_id),
                            tostring(normalized_character_id),
                            tostring(required_item_key),
                            tostring(required_item_quantity),
                            tostring(remove_error or "inventory-remove-failed")
                        )
                        callback(false, contract_row, "inventory-remove-failed")
                        return
                    end

                    continue_after_requirements()
                end)
            end)
        end

            if not requires_delivery_location then
                continue_after_delivery_location()
                return
            end

            if delivery_location_key == nil then
                callback(false, contract_row, "delivery-location-not-found")
                return
            end

            self.repository:GetDeliveryLocation(delivery_location_key, function(is_location_success, delivery_location, location_error)
                if not is_location_success then
                    callback(false, contract_row, location_error or "delivery-location-not-found")
                    return
                end

                if delivery_location == nil then
                    callback(false, contract_row, "delivery-location-not-found")
                    return
                end

                local is_near_delivery_location, proximity_error = self:ValidateDeliveryLocationProximity(player, delivery_location)

                if not is_near_delivery_location then
                    callback(false, contract_row, proximity_error)
                    return
                end

                continue_after_delivery_location()
            end)
        end)
    end)
end

function ContractService:AbandonContract(character_id, contract_id, callback)
    local normalized_character_id = normalize_positive_integer(character_id)
    local normalized_contract_id = normalize_contract_id(contract_id)

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if self.repository == nil then
        return callback_repository_missing(callback)
    end

    if normalized_character_id == nil then
        callback(false, nil, "character-id-required")
        return true
    end

    if normalized_contract_id == nil then
        callback(false, nil, "contract-id-invalid")
        return true
    end

    return self.repository:GetContractById(normalized_contract_id, function(is_get_success, contract_row, get_error)
        if not is_get_success then
            callback(false, nil, get_error or "database-error")
            return
        end

        if contract_row == nil then
            callback(false, nil, "contract-not-found")
            return
        end

        if is_contract_terminal(contract_row) then
            callback(false, contract_row, "contract-terminal")
            return
        end

        if contract_row.status ~= "accepted"
            or normalize_positive_integer(contract_row.assignee_character_id) ~= normalized_character_id
        then
            callback(false, contract_row, "not-assigned-to-character")
            return
        end

        local required_item_key = normalize_item_key(contract_row.required_item_key)
        local required_item_quantity = normalize_positive_integer(contract_row.required_item_quantity)
        local pickup_status = normalize_pickup_status(contract_row.pickup_status)
        local should_remove_cargo = pickup_status == "picked_up"
            and required_item_key ~= nil
            and required_item_quantity ~= nil
            and required_item_quantity > 0
        local inventory_bridge = nil

        local function mark_abandoned()
            self.repository:MarkContractAbandoned(
                normalized_contract_id,
                normalized_character_id,
                normalize_cancel_reason("abandoned", "abandoned"),
                function(is_mark_success, abandoned_row, mark_error)
                    if not is_mark_success then
                        if should_remove_cargo and inventory_bridge ~= nil then
                            inventory_bridge.AddItem(
                                normalized_character_id,
                                required_item_key,
                                required_item_quantity,
                                {
                                    source = "contract_abandon_compensation",
                                    contract_id = normalized_contract_id,
                                },
                                function(is_compensation_success)
                                    if not is_compensation_success then
                                        callback(false, contract_row, "inventory-compensation-failed")
                                        return
                                    end

                                    callback(false, contract_row, mark_error or "database-error")
                                end
                            )
                            return
                        end

                        callback(false, contract_row, mark_error or "database-error")
                        return
                    end

                    if abandoned_row == nil then
                        if should_remove_cargo and inventory_bridge ~= nil then
                            inventory_bridge.AddItem(
                                normalized_character_id,
                                required_item_key,
                                required_item_quantity,
                                {
                                    source = "contract_abandon_compensation",
                                    contract_id = normalized_contract_id,
                                },
                                function(is_compensation_success)
                                    if not is_compensation_success then
                                        callback(false, contract_row, "inventory-compensation-failed")
                                        return
                                    end

                                    callback(false, contract_row, "contract-terminal")
                                end
                            )
                            return
                        end

                        callback(false, contract_row, "contract-terminal")
                        return
                    end

                    Console.Log(
                        "[gr_contracts][service] Contract abandoned id=%s assignee_character_id=%s.",
                        tostring(abandoned_row.id),
                        tostring(normalized_character_id)
                    )

                    callback(true, abandoned_row, nil)
                end
            )
        end

        if not should_remove_cargo then
            mark_abandoned()
            return
        end

        inventory_bridge = resolve_inventory_bridge()

        if inventory_bridge == nil then
            callback(false, contract_row, "inventory-unavailable")
            return
        end

        inventory_bridge.RemoveItem(
            normalized_character_id,
            required_item_key,
            required_item_quantity,
            function(is_remove_success, _, remove_error)
                if not is_remove_success then
                    Console.Log(
                        "[gr_contracts][service] Contract abandon cargo remove failed contract_id=%s assignee_character_id=%s item_key=%s quantity=%s reason=%s.",
                        tostring(normalized_contract_id),
                        tostring(normalized_character_id),
                        tostring(required_item_key),
                        tostring(required_item_quantity),
                        tostring(remove_error or "inventory-remove-failed")
                    )
                    callback(false, contract_row, "cargo-remove-failed")
                    return
                end

                mark_abandoned()
            end
        )
    end)
end

function ContractService:CancelContract(character_id, contract_id, reason_or_callback, callback)
    local normalized_character_id = normalize_positive_integer(character_id)
    local normalized_contract_id = normalize_contract_id(contract_id)
    local reason = reason_or_callback

    if type(reason_or_callback) == "function" and callback == nil then
        callback = reason_or_callback
        reason = nil
    end

    if type(callback) ~= "function" then
        return false, "callback-required"
    end

    if self.repository == nil then
        return callback_repository_missing(callback)
    end

    if normalized_character_id == nil then
        callback(false, nil, "character-id-required")
        return true
    end

    if normalized_contract_id == nil then
        callback(false, nil, "contract-id-invalid")
        return true
    end

    return self.repository:GetContractById(normalized_contract_id, function(is_get_success, contract_row, get_error)
        if not is_get_success then
            callback(false, nil, get_error)
            return
        end

        if contract_row == nil then
            callback(false, nil, "contract-not-found")
            return
        end

        if is_contract_terminal(contract_row) then
            callback(false, contract_row, "contract-terminal")
            return
        end

        self.repository:MarkContractCancelled(
            normalized_contract_id,
            normalized_character_id,
            normalize_cancel_reason(reason, "admin-cancel"),
            function(is_cancel_success, cancelled_row, cancel_error)
                if not is_cancel_success then
                    callback(false, nil, cancel_error)
                    return
                end

                if cancelled_row == nil then
                    callback(false, contract_row, "contract-terminal")
                    return
                end

                Console.Log(
                    "[gr_contracts][service] Contract cancelled id=%s actor_character_id=%s reason=%s.",
                    tostring(cancelled_row.id),
                    tostring(normalized_character_id),
                    tostring(cancelled_row.cancel_reason or reason or "admin-cancel")
                )

                callback(true, cancelled_row, nil)
            end
        )
    end)
end

GRContracts.Server.ContractServiceClass = ContractService

return ContractService

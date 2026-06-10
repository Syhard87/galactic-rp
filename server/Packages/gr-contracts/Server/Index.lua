Package.Require("../Shared/Index.lua")

local ContractRepository = Package.Require("ContractRepository.lua")
local ContractService = Package.Require("ContractService.lua")

GRContracts = GRContracts or {}
GRContracts.Server = GRContracts.Server or {}

local function resolve_database_service()
    if type(GRDatabaseBridge) == "table" and type(GRDatabaseBridge.GetService) == "function" then
        return GRDatabaseBridge.GetService()
    end

    return nil
end

local function callback_service_missing(callback)
    if type(callback) == "function" then
        callback(false, nil, "contracts-service-missing")
    end

    return true
end

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

    if string_value ~= nil then
        local lowered_value = string.lower(string_value)

        if lowered_value == "true" then
            return true
        end

        if lowered_value == "false" then
            return false
        end
    end

    return fallback
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

local function normalize_job_history_limit_value(value)
    local normalized_limit = normalize_positive_integer(value)

    if normalized_limit == nil then
        return 5
    end

    if normalized_limit < 1 then
        return 1
    end

    if normalized_limit > 20 then
        return 20
    end

    return normalized_limit
end

local function read_custom_settings()
    if type(Server) ~= "table" and type(Server) ~= "userdata" then
        return nil
    end

    if type(Server.GetCustomSettings) ~= "function" then
        return nil
    end

    local is_read, custom_settings = pcall(Server.GetCustomSettings)

    if not is_read or type(custom_settings) ~= "table" then
        return nil
    end

    return custom_settings
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

local function resolve_platform_id(player_or_platform_id)
    local platform_id = get_platform_id(player_or_platform_id)

    if platform_id ~= nil then
        return platform_id
    end

    return trim_string(player_or_platform_id)
end

local function normalize_chat_submit_arguments(first_argument, second_argument)
    if get_platform_id(first_argument) ~= nil then
        return first_argument, second_argument
    end

    if get_platform_id(second_argument) ~= nil then
        return second_argument, first_argument
    end

    return nil, nil
end

local function parse_platform_id_allowlist(value)
    local allowlist = {}
    local has_entries = false

    local function add_entry(entry_value)
        local normalized_entry = trim_string(entry_value)

        if normalized_entry == nil then
            return
        end

        allowlist[normalized_entry] = true
        has_entries = true
    end

    if type(value) == "string" then
        for raw_entry in string.gmatch(value, "([^,]+)") do
            add_entry(raw_entry)
        end
    elseif type(value) == "table" then
        for _, entry_value in ipairs(value) do
            add_entry(entry_value)
        end
    end

    return allowlist, has_entries
end

local function can_use_contracts_debug_commands(player_or_platform_id)
    local platform_id = resolve_platform_id(player_or_platform_id)
    local custom_settings = nil
    local debug_commands_enabled = false
    local allowlist = nil
    local has_allowlist_entries = false

    if platform_id == nil then
        return false, nil, "platform-id-missing"
    end

    custom_settings = read_custom_settings()

    if type(custom_settings) ~= "table" then
        return false, platform_id, "custom-settings-missing"
    end

    debug_commands_enabled = normalize_boolean(custom_settings.gr_contracts_debug_commands_enabled, false)

    if not debug_commands_enabled then
        return false, platform_id, "debug-disabled"
    end

    allowlist, has_allowlist_entries = parse_platform_id_allowlist(custom_settings.gr_contracts_debug_allowed_platform_ids)

    if not has_allowlist_entries then
        return false, platform_id, "allowlist-missing"
    end

    if allowlist[platform_id] ~= true then
        return false, platform_id, "not-authorized"
    end

    return true, platform_id, nil
end

local function get_chat_command(message)
    local trimmed_message = trim_string(message)

    if trimmed_message == nil or trimmed_message:sub(1, 1) ~= "/" then
        return nil, nil
    end

    local command_name, payload = trimmed_message:match("^/(%S+)%s*(.*)$")

    if command_name == nil then
        return nil, nil
    end

    return string.lower(command_name), trim_string(payload)
end

local function resolve_active_character_id(player_or_platform_id)
    local active_character = nil

    if type(GRCharactersBridge) ~= "table" or type(GRCharactersBridge.GetActiveCharacter) ~= "function" then
        return nil
    end

    active_character = GRCharactersBridge.GetActiveCharacter(player_or_platform_id)

    if type(active_character) ~= "table" or active_character.id == nil then
        return nil
    end

    return active_character.id
end

local function format_contract_item_requirement(contract_row)
    local required_item_key = trim_string(contract_row and contract_row.required_item_key)
    local required_item_quantity = normalize_positive_integer(contract_row and contract_row.required_item_quantity)

    if required_item_key == nil or required_item_quantity == nil then
        return "item=aucun"
    end

    return string.format("item=%s x%s", tostring(required_item_key), tostring(required_item_quantity))
end

local function format_contract_destination(contract_row)
    local delivery_location_key = trim_string(contract_row and contract_row.delivery_location_key)
    local requires_delivery_location = contract_row ~= nil and contract_row.requires_delivery_location == true

    if delivery_location_key == nil or not requires_delivery_location then
        return "destination=aucune"
    end

    return string.format("destination=%s", tostring(delivery_location_key))
end

local function format_contract_pickup(contract_row)
    local pickup_location_key = trim_string(contract_row and contract_row.pickup_location_key)
    local requires_pickup_location = contract_row ~= nil and contract_row.requires_pickup_location == true

    if pickup_location_key == nil or not requires_pickup_location then
        return "pickup=aucun"
    end

    return string.format("pickup=%s", tostring(pickup_location_key))
end

local function format_contract_pickup_status(contract_row)
    local pickup_status = trim_string(contract_row and contract_row.pickup_status)

    if pickup_status == nil then
        return "pickup_status=none"
    end

    return string.format("pickup_status=%s", tostring(pickup_status))
end

local function format_contract_route_source(contract_row)
    local source_route_key = trim_string(contract_row and contract_row.source_route_key)
    local job_source = trim_string(contract_row and contract_row.job_source)

    if source_route_key == nil or job_source == nil then
        return nil
    end

    return string.format("route=%s source=%s", tostring(source_route_key), tostring(job_source))
end

local function format_contract_cargo_cleanup(contract_row)
    local cargo_cleanup_status = trim_string(contract_row and contract_row.cargo_cleanup_status)

    if trim_string(contract_row and contract_row.status) ~= "expired" or cargo_cleanup_status == nil then
        return nil
    end

    return string.format("cargo_cleanup=%s", tostring(cargo_cleanup_status))
end

local function format_deadline_value(deadline_seconds)
    local normalized_deadline_seconds = normalize_positive_integer(deadline_seconds)

    if normalized_deadline_seconds == nil then
        return nil
    end

    return string.format("deadline=%ss", tostring(normalized_deadline_seconds))
end

local function format_route_reward_preview(route_template)
    local reward_skill_xp = normalize_positive_integer(route_template and route_template.reward_skill_xp)

    if reward_skill_xp == nil or reward_skill_xp < 1 then
        return nil
    end

    return string.format("reward_xp=%s", tostring(reward_skill_xp))
end

local function append_optional_parts(base_text, ...)
    local parts = { ... }
    local resolved_text = tostring(base_text)

    for _, part in ipairs(parts) do
        if part ~= nil and part ~= "" then
            resolved_text = resolved_text .. " " .. tostring(part)
        end
    end

    return resolved_text
end

local function format_route_requirements_preview(route_template)
    local required_skill_key = trim_string(route_template and route_template.required_skill_key)
    local required_skill_level = normalize_non_negative_integer(route_template and route_template.required_skill_level) or 0
    local required_reputation_key = trim_string(route_template and route_template.required_reputation_key)
    local required_reputation_min = tonumber(route_template and route_template.required_reputation_min) or 0
    local preview_parts = {}

    if required_skill_key ~= nil and required_skill_level > 0 then
        preview_parts[#preview_parts + 1] = string.format("req_skill=%s:%s", tostring(required_skill_key), tostring(required_skill_level))
    end

    if required_reputation_key ~= nil and required_reputation_min ~= 0 then
        preview_parts[#preview_parts + 1] = string.format("req_rep=%s:%s", tostring(required_reputation_key), tostring(required_reputation_min))
    end

    if #preview_parts == 0 then
        return nil
    end

    return table.concat(preview_parts, " ")
end

local function format_route_requirements_available_value(route_template)
    local requirements_preview = format_route_requirements_preview(route_template)

    if requirements_preview == nil then
        return "aucun"
    end

    return requirements_preview
end

local function build_route_requirements_message(route_template)
    local required_skill_key = trim_string(route_template and route_template.required_skill_key)
    local required_skill_level = normalize_non_negative_integer(route_template and route_template.required_skill_level) or 0
    local required_reputation_key = trim_string(route_template and route_template.required_reputation_key)
    local required_reputation_min = tonumber(route_template and route_template.required_reputation_min) or 0

    if (required_skill_key == nil or required_skill_level < 1)
        and (required_reputation_key == nil or required_reputation_min == 0)
    then
        return "aucun."
    end

    local skill_requirement = "skill=aucune"
    local reputation_requirement = "reputation=aucune"

    if required_skill_key ~= nil and required_skill_level > 0 then
        skill_requirement = string.format("skill=%s niveau=%s", tostring(required_skill_key), tostring(required_skill_level))
    end

    if required_reputation_key ~= nil and required_reputation_min ~= 0 then
        reputation_requirement = string.format(
            "reputation=%s minimum=%s",
            tostring(required_reputation_key),
            tostring(required_reputation_min)
        )
    end

    return string.format("%s %s.", tostring(skill_requirement), tostring(reputation_requirement))
end

local function format_contract_rewards_status(contract_row)
    local rewards_status = trim_string(contract_row and contract_row.rewards_status)

    if rewards_status == nil or rewards_status == "none" then
        return nil
    end

    return string.format("rewards=%s", tostring(rewards_status))
end

local function build_contract_rewards_line(contract_row)
    local reward_skill_key = trim_string(contract_row and contract_row.reward_skill_key)
    local reward_skill_xp = normalize_positive_integer(contract_row and contract_row.reward_skill_xp)
    local reward_reputation_key = trim_string(contract_row and contract_row.reward_reputation_key)
    local reward_reputation_delta = tonumber(contract_row and contract_row.reward_reputation_delta) or 0
    local rewards_status = trim_string(contract_row and contract_row.rewards_status) or "none"
    local reputation_value = "aucune"

    if reward_reputation_key ~= nil and reward_reputation_delta ~= 0 then
        reputation_value = string.format("%s delta=%s", tostring(reward_reputation_key), tostring(reward_reputation_delta))
    end

    return string.format(
        "Recompenses contrat #%s : skill=%s xp=%s reputation=%s status=%s.",
        tostring(contract_row.id),
        tostring(reward_skill_key or "aucune"),
        tostring(reward_skill_xp or 0),
        tostring(reputation_value),
        tostring(rewards_status)
    )
end

local function build_route_template_line(route_template)
    local deadline_value = format_deadline_value(route_template and route_template.deadline_seconds)
    local reward_preview = format_route_reward_preview(route_template)
    local requirements_preview = format_route_requirements_preview(route_template)

    return append_optional_parts(
        string.format(
            "- %s item=%s x%s reward=%s pickup=%s destination=%s",
            tostring(route_template.key),
            tostring(route_template.item_key or "inconnu"),
            tostring(route_template.item_quantity or "?"),
            tostring(route_template.reward_money or 0),
            tostring(route_template.pickup_location_key or "aucun"),
            tostring(route_template.delivery_location_key or "aucune")
        ),
        deadline_value,
        reward_preview,
        requirements_preview,
        string.format("active=%s", tostring(route_template.is_active))
    )
end

local function format_route_admin_requirement_value(route_template)
    local required_skill_key = trim_string(route_template and route_template.required_skill_key)
    local required_skill_level = normalize_non_negative_integer(route_template and route_template.required_skill_level) or 0

    if required_skill_key == nil or required_skill_level < 1 then
        return "aucun"
    end

    return string.format("%s:%s", tostring(required_skill_key), tostring(required_skill_level))
end

local function build_route_admin_line(route_template)
    local deadline_seconds = normalize_positive_integer(route_template and route_template.deadline_seconds)
    local reward_skill_xp = normalize_non_negative_integer(route_template and route_template.reward_skill_xp) or 0

    return string.format(
        "- %s active=%s reward=%s deadline=%s req=%s xp=%s",
        tostring(route_template and route_template.key or "inconnue"),
        tostring(route_template and route_template.is_active == true),
        tostring(route_template and route_template.reward_money or 0),
        deadline_seconds ~= nil and string.format("%ss", tostring(deadline_seconds)) or "aucune",
        tostring(format_route_admin_requirement_value(route_template)),
        tostring(reward_skill_xp)
    )
end

local function build_route_health_summary_line(route_health)
    return string.format(
        "total=%s active=%s inactive=%s valid=%s invalid=%s uncalibrated=%s",
        tostring(route_health and route_health.total or 0),
        tostring(route_health and route_health.active or 0),
        tostring(route_health and route_health.inactive or 0),
        tostring(route_health and route_health.valid or 0),
        tostring(route_health and route_health.invalid or 0),
        tostring(route_health and route_health.uncalibrated or 0)
    )
end

local function build_route_health_issue_count_lines(route_health)
    local issue_counts = type(route_health) == "table" and route_health.issue_counts or {}
    local lines = {}
    local issue_order = {
        "pickup-position-missing",
        "delivery-position-missing",
        "pickup-missing",
        "delivery-missing",
        "pickup-inactive",
        "delivery-inactive",
        "reward-invalid",
        "deadline-invalid",
        "requirement-invalid",
        "reward-xp-invalid",
    }
    local labels = {
        ["pickup-position-missing"] = "route(s) avec pickup non calibre",
        ["delivery-position-missing"] = "route(s) avec destination non calibree",
        ["pickup-missing"] = "route(s) avec pickup introuvable",
        ["delivery-missing"] = "route(s) avec destination introuvable",
        ["pickup-inactive"] = "route(s) avec pickup inactif",
        ["delivery-inactive"] = "route(s) avec destination inactive",
        ["reward-invalid"] = "route(s) avec reward invalide",
        ["deadline-invalid"] = "route(s) avec deadline invalide",
        ["requirement-invalid"] = "route(s) avec prerequis invalide",
        ["reward-xp-invalid"] = "route(s) avec reward xp invalide",
    }

    for _, issue_code in ipairs(issue_order) do
        local count = normalize_non_negative_integer(issue_counts[issue_code]) or 0

        if count > 0 then
            lines[#lines + 1] = string.format("- %s %s", tostring(count), tostring(labels[issue_code] or issue_code))
        end
    end

    return lines
end

local function build_invalid_route_line(health_result)
    local route_template = health_result and health_result.route or {}
    local issues = type(health_result) == "table" and health_result.issues or {}
    local reason_text = "diagnostic indisponible"

    if type(issues) == "table" and #issues > 0 then
        reason_text = table.concat(issues, ", ")
    end

    return string.format(
        "- %s : %s",
        tostring(route_template.key or "inconnue"),
        tostring(reason_text)
    )
end

local function build_route_template_info_line(route_template)
    local deadline_value = format_deadline_value(route_template and route_template.deadline_seconds)
    local reward_preview = format_route_reward_preview(route_template)
    local requirements_preview = format_route_requirements_preview(route_template)

    return append_optional_parts(
        string.format(
            "item=%s x%s reward=%s pickup=%s destination=%s",
            tostring(route_template.item_key or "inconnu"),
            tostring(route_template.item_quantity or "?"),
            tostring(route_template.reward_money or 0),
            tostring(route_template.pickup_location_key or "aucun"),
            tostring(route_template.delivery_location_key or "aucune")
        ),
        deadline_value,
        reward_preview,
        requirements_preview
    )
end

local function build_job_board_line(route_template)
    local deadline_value = format_deadline_value(route_template and route_template.deadline_seconds)
    local reward_preview = format_route_reward_preview(route_template)
    local requirements_preview = format_route_requirements_preview(route_template)

    return append_optional_parts(
        string.format(
            "- %s item=%s x%s reward=%s pickup=%s destination=%s",
            tostring(route_template.key),
            tostring(route_template.item_key or "inconnu"),
            tostring(route_template.item_quantity or "?"),
            tostring(route_template.reward_money or 0),
            tostring(route_template.pickup_location_key or "aucun"),
            tostring(route_template.delivery_location_key or "aucune")
        ),
        deadline_value,
        reward_preview,
        requirements_preview
    )
end

local function build_available_job_line(availability_result)
    local route_template = availability_result and availability_result.route or {}

    return string.format(
        "- %s item=%s x%s reward=%s pickup=%s destination=%s req=%s",
        tostring(route_template.key or "inconnue"),
        tostring(route_template.item_key or "inconnu"),
        tostring(route_template.item_quantity or "?"),
        tostring(route_template.reward_money or 0),
        tostring(route_template.pickup_location_key or "aucun"),
        tostring(route_template.delivery_location_key or "aucune"),
        tostring(format_route_requirements_available_value(route_template))
    )
end

local function build_locked_job_line(availability_result)
    local route_template = availability_result and availability_result.route or {}
    local reasons = type(availability_result) == "table" and availability_result.reasons or nil
    local reason_text = "raison indisponible"

    if type(reasons) == "table" and #reasons > 0 then
        reason_text = table.concat(reasons, ", ")
    end

    return string.format(
        "- %s bloque : %s",
        tostring(route_template.key or "inconnue"),
        tostring(reason_text)
    )
end

local function build_job_progress_skill_line(skill_progress_row)
    return string.format(
        "- %s niveau=%s xp=%s",
        tostring(skill_progress_row.skill_key or "inconnue"),
        tostring(skill_progress_row.level or 0),
        tostring(skill_progress_row.xp or 0)
    )
end

local function build_job_progress_summary_line(job_progress)
    return string.format(
        "Missions disponibles=%s bloquees=%s jobs_actifs=%s/%s",
        tostring(job_progress and job_progress.available_count or 0),
        tostring(job_progress and job_progress.locked_count or 0),
        tostring(job_progress and job_progress.active_job_count or 0),
        tostring(job_progress and job_progress.max_active_job_count or 0)
    )
end

local function build_job_unlock_line(availability_result)
    local route_template = availability_result and availability_result.route or {}
    local unlock_reasons = availability_result and availability_result.unlock_reasons or {}
    local reason_text = "raison indisponible"

    if type(unlock_reasons) == "table" and #unlock_reasons > 0 then
        reason_text = table.concat(unlock_reasons, ", ")
    end

    return string.format(
        "- %s : %s",
        tostring(route_template.key or "inconnue"),
        tostring(reason_text)
    )
end

local function build_job_stats_summary_line(job_stats)
    return string.format(
        "completes=%s actifs=%s abandonnes=%s expires=%s argent_gagne=%s xp_jobs=%s taux_reussite=%s%%",
        tostring(job_stats and job_stats.completed_count or 0),
        tostring(job_stats and job_stats.active_count or 0),
        tostring(job_stats and job_stats.abandoned_or_cancelled_count or 0),
        tostring(job_stats and job_stats.expired_count or 0),
        tostring(job_stats and job_stats.money_earned or 0),
        tostring(job_stats and job_stats.granted_skill_xp or 0),
        tostring(job_stats and job_stats.success_rate_percentage or 0)
    )
end

local function build_job_history_line(contract_row)
    local source_route_key = trim_string(contract_row and contract_row.source_route_key) or "aucune"
    local pickup_location_key = trim_string(contract_row and contract_row.pickup_location_key) or "aucun"
    local delivery_location_key = trim_string(contract_row and contract_row.delivery_location_key) or "aucune"
    local rewards_status = trim_string(contract_row and contract_row.rewards_status)
    local cargo_cleanup_status = trim_string(contract_row and contract_row.cargo_cleanup_status)
    local cargo_cleanup_error = trim_string(contract_row and contract_row.cargo_cleanup_error)
    local cancel_reason = trim_string(contract_row and contract_row.cancel_reason)

    if cancel_reason == "abandoned" then
        cancel_reason = "abandon"
    end

    return append_optional_parts(
        string.format(
            "#%s status=%s route=%s reward=%s pickup=%s destination=%s",
            tostring(contract_row and contract_row.id or "?"),
            tostring(contract_row and contract_row.status or "inconnu"),
            tostring(source_route_key),
            tostring(contract_row and contract_row.reward_money or 0),
            tostring(pickup_location_key),
            tostring(delivery_location_key)
        ),
        rewards_status ~= nil and rewards_status ~= "none" and string.format("rewards=%s", tostring(rewards_status)) or nil,
        cargo_cleanup_status ~= nil and cargo_cleanup_status ~= "none" and string.format("cleanup=%s", tostring(cargo_cleanup_status)) or nil,
        cargo_cleanup_error ~= nil and cargo_cleanup_status == "failed" and string.format("error=%s", tostring(cargo_cleanup_error)) or nil,
        cancel_reason ~= nil and string.format("reason=%s", tostring(cancel_reason)) or nil
    )
end

local function build_job_requirements_status_line(route_key, requirements_result)
    local missing_requirements = type(requirements_result) == "table" and requirements_result.missing_requirements or nil

    if type(missing_requirements) == "table" and #missing_requirements > 0 then
        return string.format(
            "Prerequis mission %s : %s",
            tostring(route_key),
            tostring(table.concat(missing_requirements, " "))
        )
    end

    return string.format("Prerequis mission %s : OK.", tostring(route_key))
end

local function format_coordinate_value(value)
    if type(value) ~= "number" then
        return "NULL"
    end

    return string.format("%.1f", value)
end

local function format_radius_value(value)
    if type(value) ~= "number" then
        return "NULL"
    end

    if value % 1 == 0 then
        return string.format("%d", value)
    end

    return string.format("%.1f", value)
end

local function build_delivery_location_info_line(delivery_location)
    return string.format(
        "Point %s : x=%s y=%s z=%s radius=%s active=%s.",
        tostring(delivery_location.key),
        tostring(format_coordinate_value(delivery_location.position_x)),
        tostring(format_coordinate_value(delivery_location.position_y)),
        tostring(format_coordinate_value(delivery_location.position_z)),
        tostring(format_radius_value(delivery_location.radius)),
        tostring(delivery_location.is_active)
    )
end

local function build_contract_location_admin_line(delivery_location)
    local is_calibrated = type(delivery_location) == "table"
        and type(delivery_location.position_x) == "number"
        and type(delivery_location.position_y) == "number"
        and type(delivery_location.position_z) == "number"
    local position_value = "none"

    if is_calibrated then
        position_value = string.format(
            "%s,%s,%s",
            tostring(format_coordinate_value(delivery_location.position_x)),
            tostring(format_coordinate_value(delivery_location.position_y)),
            tostring(format_coordinate_value(delivery_location.position_z))
        )
    end

    return string.format(
        "- %s active=%s radius=%s calibrated=%s pos=%s",
        tostring(delivery_location and delivery_location.key or "inconnue"),
        tostring(delivery_location and delivery_location.is_active == true),
        tostring(format_radius_value(delivery_location and delivery_location.radius)),
        tostring(is_calibrated),
        tostring(position_value)
    )
end

local function build_contract_location_usage_line(route_usage_row)
    local route_template = route_usage_row and route_usage_row.route or {}

    return string.format(
        "- %s usage=%s active=%s item=%s x%s reward=%s",
        tostring(route_template.key or "inconnue"),
        tostring(route_usage_row and route_usage_row.usage or "unknown"),
        tostring(route_template.is_active == true),
        tostring(route_template.item_key or "inconnu"),
        tostring(route_template.item_quantity or "?"),
        tostring(route_template.reward_money or 0)
    )
end

local function build_contract_location_health_summary_line(location_health)
    local delivery_location = location_health and location_health.location or {}

    return string.format(
        "active=%s calibrated=%s radius=%s routes_total=%s routes_active=%s routes_invalides=%s",
        tostring(delivery_location.is_active == true),
        tostring(location_health and location_health.is_calibrated == true),
        tostring(format_radius_value(delivery_location.radius)),
        tostring(location_health and location_health.routes_total or 0),
        tostring(location_health and location_health.routes_active or 0),
        tostring(location_health and location_health.routes_invalid or 0)
    )
end

local function build_contract_location_impacted_route_line(route_usage_row)
    local route_template = route_usage_row and route_usage_row.route or {}

    return string.format(
        "- %s usage=%s",
        tostring(route_template.key or "inconnue"),
        tostring(route_usage_row and route_usage_row.usage or "unknown")
    )
end

local function build_unused_contract_location_line(delivery_location)
    local is_calibrated = type(delivery_location) == "table"
        and type(delivery_location.position_x) == "number"
        and type(delivery_location.position_y) == "number"
        and type(delivery_location.position_z) == "number"

    return string.format(
        "- %s active=%s calibrated=%s radius=%s",
        tostring(delivery_location and delivery_location.key or "inconnue"),
        tostring(delivery_location and delivery_location.is_active == true),
        tostring(is_calibrated),
        tostring(format_radius_value(delivery_location and delivery_location.radius))
    )
end

local function build_contract_line(contract_row)
    local payment_status = trim_string(contract_row and contract_row.payment_status)
    local item_requirement = format_contract_item_requirement(contract_row)
    local pickup = format_contract_pickup(contract_row)
    local pickup_status = format_contract_pickup_status(contract_row)
    local destination = format_contract_destination(contract_row)
    local route_source = format_contract_route_source(contract_row)
    local deadline_value = format_deadline_value(contract_row and contract_row.deadline_seconds)
    local cargo_cleanup = format_contract_cargo_cleanup(contract_row)
    local rewards_status = format_contract_rewards_status(contract_row)

    if payment_status ~= nil then
        if route_source ~= nil then
            return string.format(
                "- #%s %s reward=%s status=%s payment=%s %s %s %s %s %s %s %s %s desc=%s",
                tostring(contract_row.id),
                tostring(contract_row.type),
                tostring(contract_row.reward_money),
                tostring(contract_row.status),
                tostring(payment_status),
                tostring(item_requirement),
                tostring(pickup),
                tostring(pickup_status),
                tostring(destination),
                tostring(deadline_value or ""),
                tostring(cargo_cleanup or ""),
                tostring(rewards_status or ""),
                tostring(route_source),
                tostring(contract_row.description)
            )
        end

        return string.format(
            "- #%s %s reward=%s status=%s payment=%s %s %s %s %s %s %s %s desc=%s",
            tostring(contract_row.id),
            tostring(contract_row.type),
            tostring(contract_row.reward_money),
            tostring(contract_row.status),
            tostring(payment_status),
            tostring(item_requirement),
            tostring(pickup),
            tostring(pickup_status),
            tostring(destination),
            tostring(deadline_value or ""),
            tostring(cargo_cleanup or ""),
            tostring(rewards_status or ""),
            tostring(contract_row.description)
        )
    end

    if route_source ~= nil then
        return string.format(
            "- #%s %s reward=%s status=%s %s %s %s %s %s %s %s %s desc=%s",
            tostring(contract_row.id),
            tostring(contract_row.type),
            tostring(contract_row.reward_money),
            tostring(contract_row.status),
            tostring(item_requirement),
            tostring(pickup),
            tostring(pickup_status),
            tostring(destination),
            tostring(deadline_value or ""),
            tostring(cargo_cleanup or ""),
            tostring(rewards_status or ""),
            tostring(route_source),
            tostring(contract_row.description)
        )
    end

    return string.format(
        "- #%s %s reward=%s status=%s %s %s %s %s %s %s %s desc=%s",
        tostring(contract_row.id),
        tostring(contract_row.type),
        tostring(contract_row.reward_money),
        tostring(contract_row.status),
        tostring(item_requirement),
        tostring(pickup),
        tostring(pickup_status),
        tostring(destination),
        tostring(deadline_value or ""),
        tostring(cargo_cleanup or ""),
        tostring(rewards_status or ""),
        tostring(contract_row.description)
    )
end

local function build_my_contract_line(contract_row)
    local payment_status = trim_string(contract_row and contract_row.payment_status)
    local item_requirement = format_contract_item_requirement(contract_row)
    local pickup = format_contract_pickup(contract_row)
    local pickup_status = format_contract_pickup_status(contract_row)
    local destination = format_contract_destination(contract_row)
    local route_source = format_contract_route_source(contract_row)
    local deadline_value = format_deadline_value(contract_row and contract_row.deadline_seconds)
    local cargo_cleanup = format_contract_cargo_cleanup(contract_row)
    local rewards_status = format_contract_rewards_status(contract_row)

    if payment_status ~= nil then
        if route_source ~= nil then
            return string.format(
                "- #%s %s reward=%s status=%s payment=%s role=%s %s %s %s %s %s %s %s %s",
                tostring(contract_row.id),
                tostring(contract_row.type),
                tostring(contract_row.reward_money),
                tostring(contract_row.status),
                tostring(payment_status),
                tostring(contract_row.role or "unknown"),
                tostring(item_requirement),
                tostring(pickup),
                tostring(pickup_status),
                tostring(destination),
                tostring(deadline_value or ""),
                tostring(cargo_cleanup or ""),
                tostring(rewards_status or ""),
                tostring(route_source)
            )
        end

        return string.format(
            "- #%s %s reward=%s status=%s payment=%s role=%s %s %s %s %s %s %s %s",
            tostring(contract_row.id),
            tostring(contract_row.type),
            tostring(contract_row.reward_money),
            tostring(contract_row.status),
            tostring(payment_status),
            tostring(contract_row.role or "unknown"),
            tostring(item_requirement),
            tostring(pickup),
            tostring(pickup_status),
            tostring(destination),
            tostring(deadline_value or ""),
            tostring(cargo_cleanup or ""),
            tostring(rewards_status or "")
        )
    end

    if route_source ~= nil then
        return string.format(
            "- #%s %s reward=%s status=%s role=%s %s %s %s %s %s %s %s %s",
            tostring(contract_row.id),
            tostring(contract_row.type),
            tostring(contract_row.reward_money),
            tostring(contract_row.status),
            tostring(contract_row.role or "unknown"),
            tostring(item_requirement),
            tostring(pickup),
            tostring(pickup_status),
            tostring(destination),
            tostring(deadline_value or ""),
            tostring(cargo_cleanup or ""),
            tostring(rewards_status or ""),
            tostring(route_source)
        )
    end

    return string.format(
        "- #%s %s reward=%s status=%s role=%s %s %s %s %s %s %s %s",
        tostring(contract_row.id),
        tostring(contract_row.type),
        tostring(contract_row.reward_money),
        tostring(contract_row.status),
        tostring(contract_row.role or "unknown"),
        tostring(item_requirement),
        tostring(pickup),
        tostring(pickup_status),
        tostring(destination),
        tostring(deadline_value or ""),
        tostring(cargo_cleanup or ""),
        tostring(rewards_status or "")
    )
end

local function build_expired_contract_line(contract_row)
    local line = string.format(
        "#%s status=%s cargo_cleanup=%s %s",
        tostring(contract_row.id),
        tostring(contract_row.status),
        tostring(trim_string(contract_row.cargo_cleanup_status) or "none"),
        tostring(format_contract_item_requirement(contract_row))
    )
    local cleanup_error = trim_string(contract_row and contract_row.cargo_cleanup_error)

    if cleanup_error ~= nil then
        line = string.format("%s error=%s", tostring(line), tostring(cleanup_error))
    end

    return line
end

local database_service = resolve_database_service()

GRContracts.Server.Repository = ContractRepository.Create(database_service)
GRContracts.Server.Service = ContractService.Create(GRContracts.Server.Repository)

if database_service ~= nil then
    Console.Log("[gr_contracts][server] Database service resolved through GRDatabaseBridge.")
else
    Console.Log("[gr_contracts][server] Database service unavailable because GRDatabaseBridge is missing.")
end

GRContractsBridge = GRContractsBridge or {}

GRContractsBridge.GetService = function()
    return GRContracts.Server.Service
end

GRContractsBridge.CreateContract = function(character_id, contract_type, reward_money, description, callback)
    if GRContracts.Server.Service == nil then
        return callback_service_missing(callback)
    end

    return GRContracts.Server.Service:CreateContract(character_id, contract_type, reward_money, description, callback)
end

GRContractsBridge.CreateDeliveryContract = function(character_id, item_key, quantity, reward_money, description, callback)
    if GRContracts.Server.Service == nil then
        return callback_service_missing(callback)
    end

    return GRContracts.Server.Service:CreateDeliveryContract(
        character_id,
        item_key,
        quantity,
        reward_money,
        description,
        callback
    )
end

GRContractsBridge.CreateDeliveryContractAt = function(character_id, item_key, quantity, reward_money, location_key, description, callback)
    if GRContracts.Server.Service == nil then
        return callback_service_missing(callback)
    end

    return GRContracts.Server.Service:CreateDeliveryContractAt(
        character_id,
        item_key,
        quantity,
        reward_money,
        location_key,
        description,
        callback
    )
end

GRContractsBridge.CreateHaulContract = function(character_id, item_key, quantity, reward_money, pickup_location_key, delivery_location_key, description, callback)
    if GRContracts.Server.Service == nil then
        return callback_service_missing(callback)
    end

    return GRContracts.Server.Service:CreateHaulContract(
        character_id,
        item_key,
        quantity,
        reward_money,
        pickup_location_key,
        delivery_location_key,
        description,
        callback
    )
end

GRContractsBridge.CreateHaulContractFromRoute = function(character_id, route_key, callback)
    if GRContracts.Server.Service == nil then
        return callback_service_missing(callback)
    end

    return GRContracts.Server.Service:CreateHaulContractFromRoute(character_id, route_key, callback)
end

GRContractsBridge.ListOpenContracts = function(callback)
    if GRContracts.Server.Service == nil then
        return callback_service_missing(callback)
    end

    return GRContracts.Server.Service:ListOpenContracts(callback)
end

GRContractsBridge.ListMyContracts = function(character_id, callback)
    if GRContracts.Server.Service == nil then
        return callback_service_missing(callback)
    end

    return GRContracts.Server.Service:ListMyContracts(character_id, callback)
end

GRContractsBridge.AcceptContract = function(character_id, contract_id, callback)
    if GRContracts.Server.Service == nil then
        return callback_service_missing(callback)
    end

    return GRContracts.Server.Service:AcceptContract(character_id, contract_id, callback)
end

GRContractsBridge.CompleteContract = function(character_id, contract_id, callback)
    if GRContracts.Server.Service == nil then
        return callback_service_missing(callback)
    end

    return GRContracts.Server.Service:CompleteContract(character_id, contract_id, callback)
end

GRContractsBridge.PickupContract = function(character_id, player, contract_id, callback)
    if GRContracts.Server.Service == nil then
        return callback_service_missing(callback)
    end

    return GRContracts.Server.Service:PickupContract(character_id, player, contract_id, callback)
end

GRContractsBridge.AbandonContract = function(character_id, contract_id, callback)
    if GRContracts.Server.Service == nil then
        return callback_service_missing(callback)
    end

    return GRContracts.Server.Service:AbandonContract(character_id, contract_id, callback)
end

GRContractsBridge.CancelContract = function(character_id, contract_id, reason, callback)
    if GRContracts.Server.Service == nil then
        return callback_service_missing(callback)
    end

    return GRContracts.Server.Service:CancelContract(character_id, contract_id, reason, callback)
end

GRContractsBridge.ListDeliveryLocations = function(callback)
    if GRContracts.Server.Service == nil then
        return callback_service_missing(callback)
    end

    return GRContracts.Server.Service:ListDeliveryLocations(callback)
end

GRContractsBridge.ListRouteTemplates = function(callback)
    if GRContracts.Server.Service == nil then
        return callback_service_missing(callback)
    end

    return GRContracts.Server.Service:ListRouteTemplates(callback)
end

GRContractsBridge.ListAllRouteTemplates = function(callback)
    if GRContracts.Server.Service == nil then
        return callback_service_missing(callback)
    end

    return GRContracts.Server.Service:ListAllRouteTemplates(callback)
end

GRContractsBridge.CreateRouteTemplate = function(route_key, item_key, quantity, reward_money, pickup_location_key, delivery_location_key, description, callback)
    if GRContracts.Server.Service == nil then
        return callback_service_missing(callback)
    end

    return GRContracts.Server.Service:CreateRouteTemplate(
        route_key,
        item_key,
        quantity,
        reward_money,
        pickup_location_key,
        delivery_location_key,
        description,
        callback
    )
end

GRContractsBridge.ValidateRouteTemplate = function(route_key, callback)
    if GRContracts.Server.Service == nil then
        return callback_service_missing(callback)
    end

    return GRContracts.Server.Service:ValidateRouteTemplate(route_key, callback)
end

GRContractsBridge.GetRouteHealth = function(callback)
    if GRContracts.Server.Service == nil then
        return callback_service_missing(callback)
    end

    return GRContracts.Server.Service:GetRouteHealth(callback)
end

GRContractsBridge.ListInvalidRoutes = function(callback)
    if GRContracts.Server.Service == nil then
        return callback_service_missing(callback)
    end

    return GRContracts.Server.Service:ListInvalidRoutes(callback)
end

GRContractsBridge.SetRouteDescription = function(route_key, description, callback)
    if GRContracts.Server.Service == nil then
        return callback_service_missing(callback)
    end

    return GRContracts.Server.Service:SetRouteDescription(route_key, description, callback)
end

GRContractsBridge.GetRouteTemplate = function(route_key, callback)
    if GRContracts.Server.Service == nil then
        return callback_service_missing(callback)
    end

    return GRContracts.Server.Service:GetRouteTemplate(route_key, callback)
end

GRContractsBridge.SetRouteActive = function(route_key, is_active, callback)
    if GRContracts.Server.Service == nil then
        return callback_service_missing(callback)
    end

    return GRContracts.Server.Service:SetRouteActive(route_key, is_active, callback)
end

GRContractsBridge.ForceSetRouteActive = function(route_key, is_active, callback)
    if GRContracts.Server.Service == nil then
        return callback_service_missing(callback)
    end

    return GRContracts.Server.Service:ForceSetRouteActive(route_key, is_active, callback)
end

GRContractsBridge.SetRouteDeadline = function(route_key, deadline_seconds, callback)
    if GRContracts.Server.Service == nil then
        return callback_service_missing(callback)
    end

    return GRContracts.Server.Service:SetRouteDeadline(route_key, deadline_seconds, callback)
end

GRContractsBridge.SetRouteReward = function(route_key, reward_money, reward_skill_xp, callback)
    if GRContracts.Server.Service == nil then
        return callback_service_missing(callback)
    end

    return GRContracts.Server.Service:SetRouteReward(route_key, reward_money, reward_skill_xp, callback)
end

GRContractsBridge.SetRouteRequirement = function(route_key, required_skill_key, required_skill_level, callback)
    if GRContracts.Server.Service == nil then
        return callback_service_missing(callback)
    end

    return GRContracts.Server.Service:SetRouteRequirement(route_key, required_skill_key, required_skill_level, callback)
end

GRContractsBridge.ListJobBoardRoutes = function(callback)
    if GRContracts.Server.Service == nil then
        return callback_service_missing(callback)
    end

    return GRContracts.Server.Service:ListJobBoardRoutes(callback)
end

GRContractsBridge.GetJobBoardRoute = function(route_key, callback)
    if GRContracts.Server.Service == nil then
        return callback_service_missing(callback)
    end

    return GRContracts.Server.Service:GetJobBoardRoute(route_key, callback)
end

GRContractsBridge.GetJobRequirements = function(character_id, route_key, callback)
    if GRContracts.Server.Service == nil then
        return callback_service_missing(callback)
    end

    return GRContracts.Server.Service:GetJobRequirements(character_id, route_key, callback)
end

GRContractsBridge.GetAvailableJobs = function(character_id, callback)
    if GRContracts.Server.Service == nil then
        return callback_service_missing(callback)
    end

    return GRContracts.Server.Service:GetAvailableJobs(character_id, callback)
end

GRContractsBridge.GetLockedJobs = function(character_id, callback)
    if GRContracts.Server.Service == nil then
        return callback_service_missing(callback)
    end

    return GRContracts.Server.Service:GetLockedJobs(character_id, callback)
end

GRContractsBridge.GetJobProgress = function(character_id, callback)
    if GRContracts.Server.Service == nil then
        return callback_service_missing(callback)
    end

    return GRContracts.Server.Service:GetJobProgress(character_id, callback)
end

GRContractsBridge.GetJobUnlocks = function(character_id, callback)
    if GRContracts.Server.Service == nil then
        return callback_service_missing(callback)
    end

    return GRContracts.Server.Service:GetJobUnlocks(character_id, callback)
end

GRContractsBridge.GetJobStats = function(character_id, callback)
    if GRContracts.Server.Service == nil then
        return callback_service_missing(callback)
    end

    return GRContracts.Server.Service:GetJobStats(character_id, callback)
end

GRContractsBridge.GetJobHistory = function(character_id, limit, callback)
    if GRContracts.Server.Service == nil then
        return callback_service_missing(callback)
    end

    return GRContracts.Server.Service:GetJobHistory(character_id, limit, callback)
end

GRContractsBridge.TakeJobFromRoute = function(character_id, route_key, callback)
    if GRContracts.Server.Service == nil then
        return callback_service_missing(callback)
    end

    return GRContracts.Server.Service:TakeJobFromRoute(character_id, route_key, callback)
end

GRContractsBridge.GetContractDeadline = function(character_id, contract_id, callback)
    if GRContracts.Server.Service == nil then
        return callback_service_missing(callback)
    end

    return GRContracts.Server.Service:GetContractDeadline(character_id, contract_id, callback)
end

GRContractsBridge.GetContractRewards = function(character_id, contract_id, callback)
    if GRContracts.Server.Service == nil then
        return callback_service_missing(callback)
    end

    return GRContracts.Server.Service:GetContractRewards(character_id, contract_id, callback)
end

GRContractsBridge.GrantContractRewards = function(contract_id, callback)
    if GRContracts.Server.Service == nil then
        return callback_service_missing(callback)
    end

    return GRContracts.Server.Service:GrantContractRewards(contract_id, callback)
end

GRContractsBridge.ExpireContracts = function(callback)
    if GRContracts.Server.Service == nil then
        return callback_service_missing(callback)
    end

    return GRContracts.Server.Service:ExpireContracts(callback)
end

GRContractsBridge.CleanupExpiredContractCargo = function(contract_id, callback)
    if GRContracts.Server.Service == nil then
        return callback_service_missing(callback)
    end

    return GRContracts.Server.Service:CleanupExpiredContractCargo(contract_id, callback)
end

GRContractsBridge.ListExpiredContracts = function(callback)
    if GRContracts.Server.Service == nil then
        return callback_service_missing(callback)
    end

    return GRContracts.Server.Service:ListExpiredContracts(callback)
end

GRContractsBridge.GetDeliveryLocation = function(location_key, callback)
    if GRContracts.Server.Service == nil then
        return callback_service_missing(callback)
    end

    return GRContracts.Server.Service:GetDeliveryLocation(location_key, callback)
end

GRContractsBridge.GetDeliveryLocationInfo = function(location_key, callback)
    if GRContracts.Server.Service == nil then
        return callback_service_missing(callback)
    end

    return GRContracts.Server.Service:GetDeliveryLocationInfo(location_key, callback)
end

GRContractsBridge.ListAllContractLocations = function(callback)
    if GRContracts.Server.Service == nil then
        return callback_service_missing(callback)
    end

    return GRContracts.Server.Service:ListAllContractLocations(callback)
end

GRContractsBridge.GetContractLocationRoutes = function(location_key, callback)
    if GRContracts.Server.Service == nil then
        return callback_service_missing(callback)
    end

    return GRContracts.Server.Service:GetContractLocationRoutes(location_key, callback)
end

GRContractsBridge.GetContractLocationHealth = function(location_key, callback)
    if GRContracts.Server.Service == nil then
        return callback_service_missing(callback)
    end

    return GRContracts.Server.Service:GetContractLocationHealth(location_key, callback)
end

GRContractsBridge.ListUnusedContractLocations = function(callback)
    if GRContracts.Server.Service == nil then
        return callback_service_missing(callback)
    end

    return GRContracts.Server.Service:ListUnusedContractLocations(callback)
end

GRContractsBridge.CreateContractLocation = function(location_key, radius, name, callback)
    if GRContracts.Server.Service == nil then
        return callback_service_missing(callback)
    end

    return GRContracts.Server.Service:CreateContractLocation(location_key, radius, name, callback)
end

GRContractsBridge.SetContractLocationActive = function(location_key, is_active, callback)
    if GRContracts.Server.Service == nil then
        return callback_service_missing(callback)
    end

    return GRContracts.Server.Service:SetContractLocationActive(location_key, is_active, callback)
end

GRContractsBridge.SetContractLocationRadius = function(location_key, radius, callback)
    if GRContracts.Server.Service == nil then
        return callback_service_missing(callback)
    end

    return GRContracts.Server.Service:SetContractLocationRadius(location_key, radius, callback)
end

GRContractsBridge.SetContractLocationName = function(location_key, name, callback)
    if GRContracts.Server.Service == nil then
        return callback_service_missing(callback)
    end

    return GRContracts.Server.Service:SetContractLocationName(location_key, name, callback)
end

GRContractsBridge.SetDeliveryLocationHere = function(player, location_key, radius, callback)
    if GRContracts.Server.Service == nil then
        return callback_service_missing(callback)
    end

    return GRContracts.Server.Service:SetDeliveryLocationHere(player, location_key, radius, callback)
end

Package.Export("GRContractsBridge", GRContractsBridge)

if type(Chat) == "table" and type(Chat.Subscribe) == "function" and type(Chat.SendMessage) == "function" then
    Chat.Subscribe("PlayerSubmit", function(first_argument, second_argument)
        local player, message = normalize_chat_submit_arguments(first_argument, second_argument)
        local command_name = nil
        local payload = nil

        if player == nil then
            return
        end

        command_name, payload = get_chat_command(message)

        if command_name ~= "contracts"
            and command_name ~= "mycontracts"
            and command_name ~= "contractroutes"
            and command_name ~= "allcontractroutes"
            and command_name ~= "createroute"
            and command_name ~= "contractrouteinfo"
            and command_name ~= "routehealth"
            and command_name ~= "setroutedescription"
            and command_name ~= "validateroute"
            and command_name ~= "jobboard"
            and command_name ~= "jobinfo"
            and command_name ~= "availablejobs"
            and command_name ~= "lockedjobs"
            and command_name ~= "jobprogress"
            and command_name ~= "jobunlocks"
            and command_name ~= "jobstats"
            and command_name ~= "jobhistory"
            and command_name ~= "jobrequirements"
            and command_name ~= "createcontract"
            and command_name ~= "createdeliverycontract"
            and command_name ~= "createdeliverycontractat"
            and command_name ~= "createhaulcontract"
            and command_name ~= "createhaulfromroute"
            and command_name ~= "takejob"
            and command_name ~= "deliverylocations"
            and command_name ~= "allcontractlocations"
            and command_name ~= "deliverylocationinfo"
            and command_name ~= "contractlocationroutes"
            and command_name ~= "contractlocationhealth"
            and command_name ~= "unusedcontractlocations"
            and command_name ~= "createcontractlocation"
            and command_name ~= "setcontractlocationactive"
            and command_name ~= "setcontractlocationradius"
            and command_name ~= "setcontractlocationname"
            and command_name ~= "setdeliverylocationhere"
            and command_name ~= "acceptcontract"
            and command_name ~= "pickupcontract"
            and command_name ~= "abandoncontract"
            and command_name ~= "completecontract"
            and command_name ~= "cancelcontract"
            and command_name ~= "contractdeadline"
            and command_name ~= "contractrewards"
            and command_name ~= "grantcontractrewards"
            and command_name ~= "expirecontracts"
            and command_name ~= "cleanupcontractcargo"
            and command_name ~= "expiredcontracts"
            and command_name ~= "setrouteactive"
            and command_name ~= "forcerouteactive"
            and command_name ~= "setroutedeadline"
            and command_name ~= "setroutereward"
            and command_name ~= "setrouterequirement"
            and command_name ~= "invalidroutes"
        then
            return
        end

        local is_allowed = false
        local platform_id = nil
        local guard_error = nil

        is_allowed, platform_id, guard_error = can_use_contracts_debug_commands(player)

        if not is_allowed then
            Console.Log(
                "[gr_contracts][server] Contracts debug command denied platform_id=%s reason=%s.",
                tostring(platform_id),
                tostring(guard_error)
            )
            Chat.SendMessage(player, "Commande contrats desactivee.")
            return false
        end

        local active_character_id = resolve_active_character_id(player)

        if active_character_id == nil then
            Chat.SendMessage(player, "Personnage actif introuvable.")
            return false
        end

        if command_name == "contracts" then
            GRContracts.Server.Service:ListOpenContracts(function(is_success, contract_rows, error)
                if not is_success then
                    Chat.SendMessage(player, "Contrats indisponibles.")
                    return
                end

                if type(contract_rows) ~= "table" or #contract_rows == 0 then
                    Chat.SendMessage(player, "Aucun contrat ouvert.")
                    return
                end

                Chat.SendMessage(player, "Contrats ouverts :")

                for _, contract_row in ipairs(contract_rows) do
                    Chat.SendMessage(player, build_contract_line(contract_row))
                end
            end)

            return false
        end

        if command_name == "contractroutes" then
            GRContracts.Server.Service:ListRouteTemplates(function(is_success, route_templates, error)
                if not is_success then
                    Chat.SendMessage(player, "Routes transport indisponibles.")
                    return
                end

                if type(route_templates) ~= "table" or #route_templates == 0 then
                    Chat.SendMessage(player, "Aucune route transport.")
                    return
                end

                Chat.SendMessage(player, "Routes transport :")

                for _, route_template in ipairs(route_templates) do
                    Chat.SendMessage(player, build_route_template_line(route_template))
                end
            end)

            return false
        end

        if command_name == "allcontractroutes" then
            GRContracts.Server.Service:ListAllRouteTemplates(function(is_success, route_templates, error)
                if not is_success then
                    Chat.SendMessage(player, "Routes transport indisponibles.")
                    return
                end

                if type(route_templates) ~= "table" or #route_templates == 0 then
                    Chat.SendMessage(player, "Aucune route transport.")
                    return
                end

                Chat.SendMessage(player, "Toutes les routes transport :")

                for _, route_template in ipairs(route_templates) do
                    Chat.SendMessage(player, build_route_admin_line(route_template))
                end
            end)

            return false
        end

        if command_name == "routehealth" then
            GRContracts.Server.Service:GetRouteHealth(function(is_success, route_health, error)
                local issue_lines = nil

                if not is_success then
                    Chat.SendMessage(player, "Diagnostic routes indisponible.")
                    return
                end

                Chat.SendMessage(player, "Route health :")
                Chat.SendMessage(player, build_route_health_summary_line(route_health))

                issue_lines = build_route_health_issue_count_lines(route_health)

                if #issue_lines > 0 then
                    Chat.SendMessage(player, "Issues principales :")

                    for _, issue_line in ipairs(issue_lines) do
                        Chat.SendMessage(player, issue_line)
                    end
                end
            end)

            return false
        end

        if command_name == "createroute" then
            if payload == nil then
                Chat.SendMessage(player, "Usage : /createroute <route_key> <item_key> <quantity> <reward_money> <pickup_location_key> <delivery_location_key> <description>")
                return false
            end

            local route_key, item_key, quantity_text, reward_money_text, pickup_location_key, delivery_location_key, description =
                payload:match("^(%S+)%s+(%S+)%s+(%S+)%s+([+-]?%d+)%s+(%S+)%s+(%S+)%s+(.+)$")

            if route_key == nil then
                Chat.SendMessage(player, "Usage : /createroute <route_key> <item_key> <quantity> <reward_money> <pickup_location_key> <delivery_location_key> <description>")
                return false
            end

            GRContracts.Server.Service:CreateRouteTemplate(
                route_key,
                item_key,
                quantity_text,
                reward_money_text,
                pickup_location_key,
                delivery_location_key,
                description,
                function(is_success, route_template, error)
                    if not is_success then
                        if error == "invalid-route-key" then
                            Chat.SendMessage(player, "Creation route impossible : route_key invalide.")
                            return
                        end

                        if error == "route-already-exists" then
                            Chat.SendMessage(player, "Creation route impossible : route deja existante.")
                            return
                        end

                        if error == "invalid-item-key" then
                            Chat.SendMessage(player, "Creation route impossible : item invalide.")
                            return
                        end

                        if error == "invalid-quantity" then
                            Chat.SendMessage(player, "Creation route impossible : quantite invalide.")
                            return
                        end

                        if error == "invalid-reward" then
                            Chat.SendMessage(player, "Creation route impossible : reward invalide.")
                            return
                        end

                        if error == "invalid-pickup-location" then
                            Chat.SendMessage(player, "Creation route impossible : pickup introuvable.")
                            return
                        end

                        if error == "invalid-delivery-location" then
                            Chat.SendMessage(player, "Creation route impossible : destination introuvable.")
                            return
                        end

                        if error == "invalid-description" then
                            Chat.SendMessage(player, "Creation route impossible : description invalide.")
                            return
                        end

                        Chat.SendMessage(player, "Creation route impossible.")
                        return
                    end

                    Chat.SendMessage(
                        player,
                        string.format(
                            "Route creee : %s item=%s x%s reward=%s pickup=%s destination=%s active=%s.",
                            tostring(route_template.key),
                            tostring(route_template.item_key or "inconnu"),
                            tostring(route_template.item_quantity or "?"),
                            tostring(route_template.reward_money or 0),
                            tostring(route_template.pickup_location_key or "aucun"),
                            tostring(route_template.delivery_location_key or "aucune"),
                            tostring(route_template.is_active == true)
                        )
                    )
                    Chat.SendMessage(
                        player,
                        string.format(
                            "Utilisez /validateroute %s puis /setrouteactive %s true.",
                            tostring(route_template.key),
                            tostring(route_template.key)
                        )
                    )
                end
            )

            return false
        end

        if command_name == "validateroute" then
            if payload == nil then
                Chat.SendMessage(player, "Usage : /validateroute <route_key>")
                return false
            end

            GRContracts.Server.Service:ValidateRouteTemplate(payload, function(is_success, health_result, error)
                local route_template = type(health_result) == "table" and health_result.route or nil

                if not is_success or route_template == nil then
                    Chat.SendMessage(player, "Route introuvable.")
                    return
                end

                if health_result.is_valid == true then
                    Chat.SendMessage(player, string.format("Route %s : OK.", tostring(route_template.key)))
                    Chat.SendMessage(player, build_route_template_info_line(route_template))
                    return
                end

                Chat.SendMessage(player, string.format("Route %s : INVALID.", tostring(route_template.key)))
                Chat.SendMessage(player, "Issues :")

                for _, issue_text in ipairs(health_result.issues or {}) do
                    Chat.SendMessage(player, string.format("- %s", tostring(issue_text)))
                end
            end)

            return false
        end

        if command_name == "jobboard" then
            GRContracts.Server.Service:ListJobBoardRoutes(function(is_success, route_templates, error)
                if not is_success then
                    Chat.SendMessage(player, "Missions indisponibles.")
                    return
                end

                if type(route_templates) ~= "table" or #route_templates == 0 then
                    Chat.SendMessage(player, "Aucune mission disponible.")
                    return
                end

                Chat.SendMessage(player, "Missions disponibles :")

                for _, route_template in ipairs(route_templates) do
                    Chat.SendMessage(player, build_job_board_line(route_template))
                end
            end)

            return false
        end

        if command_name == "invalidroutes" then
            GRContracts.Server.Service:ListInvalidRoutes(function(is_success, invalid_rows, error)
                if not is_success then
                    Chat.SendMessage(player, "Routes invalides indisponibles.")
                    return
                end

                if type(invalid_rows) ~= "table" or #invalid_rows == 0 then
                    Chat.SendMessage(player, "Aucune route invalide detectee.")
                    return
                end

                Chat.SendMessage(player, "Routes invalides :")

                for _, health_result in ipairs(invalid_rows) do
                    Chat.SendMessage(player, build_invalid_route_line(health_result))
                end
            end)

            return false
        end

        if command_name == "availablejobs" then
            GRContracts.Server.Service:GetAvailableJobs(active_character_id, function(is_success, availability_rows, error)
                if not is_success then
                    Chat.SendMessage(player, "Missions indisponibles.")
                    return
                end

                if type(availability_rows) ~= "table" or #availability_rows == 0 then
                    Chat.SendMessage(player, "Aucune mission disponible pour votre personnage.")
                    return
                end

                Chat.SendMessage(player, "Missions disponibles :")

                for _, availability_result in ipairs(availability_rows) do
                    Chat.SendMessage(player, build_available_job_line(availability_result))
                end
            end)

            return false
        end

        if command_name == "lockedjobs" then
            GRContracts.Server.Service:GetLockedJobs(active_character_id, function(is_success, availability_rows, error)
                if not is_success then
                    Chat.SendMessage(player, "Missions indisponibles.")
                    return
                end

                if type(availability_rows) ~= "table" or #availability_rows == 0 then
                    Chat.SendMessage(player, "Aucune mission bloquee pour votre personnage.")
                    return
                end

                Chat.SendMessage(player, "Missions bloquees :")

                for _, availability_result in ipairs(availability_rows) do
                    Chat.SendMessage(player, build_locked_job_line(availability_result))
                end
            end)

            return false
        end

        if command_name == "jobprogress" then
            GRContracts.Server.Service:GetJobProgress(active_character_id, function(is_success, job_progress, error)
                if not is_success then
                    Chat.SendMessage(player, "Progression jobs indisponible.")
                    return
                end

                if job_progress.has_required_skills ~= true then
                    Chat.SendMessage(player, "Progression jobs : aucun skill requis par les routes actuelles.")
                    Chat.SendMessage(player, build_job_progress_summary_line(job_progress))
                    return
                end

                Chat.SendMessage(player, "Progression jobs :")

                for _, skill_progress_row in ipairs(job_progress.skills or {}) do
                    Chat.SendMessage(player, build_job_progress_skill_line(skill_progress_row))
                end

                Chat.SendMessage(player, build_job_progress_summary_line(job_progress))
            end)

            return false
        end

        if command_name == "jobunlocks" then
            GRContracts.Server.Service:GetJobUnlocks(active_character_id, function(is_success, unlock_rows, error)
                if not is_success then
                    Chat.SendMessage(player, "Deblocages jobs indisponibles.")
                    return
                end

                if type(unlock_rows) ~= "table" or #unlock_rows == 0 then
                    Chat.SendMessage(player, "Tous les jobs actifs sont disponibles pour votre personnage.")
                    return
                end

                Chat.SendMessage(player, "Deblocages jobs :")

                for _, unlock_row in ipairs(unlock_rows) do
                    Chat.SendMessage(player, build_job_unlock_line(unlock_row))
                end
            end)

            return false
        end

        if command_name == "jobstats" then
            GRContracts.Server.Service:GetJobStats(active_character_id, function(is_success, job_stats, error)
                if not is_success then
                    Chat.SendMessage(player, "Stats jobs indisponibles.")
                    return
                end

                Chat.SendMessage(player, "Stats jobs :")
                Chat.SendMessage(player, build_job_stats_summary_line(job_stats))
            end)

            return false
        end

        if command_name == "jobhistory" then
            local history_limit = normalize_job_history_limit_value(payload)

            GRContracts.Server.Service:GetJobHistory(active_character_id, history_limit, function(is_success, job_history, error)
                local history_rows = type(job_history) == "table" and job_history.rows or nil

                if not is_success then
                    Chat.SendMessage(player, "Historique jobs indisponible.")
                    return
                end

                if type(history_rows) ~= "table" or #history_rows == 0 then
                    Chat.SendMessage(player, "Aucun historique job pour votre personnage.")
                    return
                end

                Chat.SendMessage(player, "Historique jobs :")

                for _, contract_row in ipairs(history_rows) do
                    Chat.SendMessage(player, build_job_history_line(contract_row))
                end
            end)

            return false
        end

        if command_name == "setroutedescription" then
            if payload == nil then
                Chat.SendMessage(player, "Usage : /setroutedescription <route_key> <description>")
                return false
            end

            local route_key, description = payload:match("^(%S+)%s+(.+)$")

            if route_key == nil or description == nil then
                Chat.SendMessage(player, "Usage : /setroutedescription <route_key> <description>")
                return false
            end

            GRContracts.Server.Service:SetRouteDescription(route_key, description, function(is_success, route_template, error)
                if not is_success then
                    if error == "route-not-found" or error == "invalid-route-key" then
                        Chat.SendMessage(player, "Route introuvable.")
                        return
                    end

                    if error == "invalid-description" then
                        Chat.SendMessage(player, "Description invalide.")
                        return
                    end

                    Chat.SendMessage(player, "Route indisponible.")
                    return
                end

                Chat.SendMessage(player, string.format("Route %s description mise a jour.", tostring(route_template.key)))
            end)

            return false
        end

        if command_name == "setrouteactive" then
            if payload == nil then
                Chat.SendMessage(player, "Usage : /setrouteactive <route_key> <true|false>")
                return false
            end

            local route_key, active_text = payload:match("^(%S+)%s+(%S+)$")

            if route_key == nil or active_text == nil then
                Chat.SendMessage(player, "Usage : /setrouteactive <route_key> <true|false>")
                return false
            end

            GRContracts.Server.Service:SetRouteActive(route_key, active_text, function(is_success, route_template, error)
                if not is_success then
                    if error == "route-not-found" or error == "invalid-route-key" then
                        Chat.SendMessage(player, "Route introuvable.")
                        return
                    end

                    if error == "invalid-active-value" then
                        Chat.SendMessage(player, "Valeur active invalide.")
                        return
                    end

                    if error == "route-invalid" then
                        Chat.SendMessage(player, "Activation route impossible : route invalide.")
                        Chat.SendMessage(player, "Issues :")

                        for _, issue_text in ipairs((route_template and route_template.issues) or {}) do
                            Chat.SendMessage(player, string.format("- %s", tostring(issue_text)))
                        end

                        Chat.SendMessage(
                            player,
                            string.format(
                                "Utilisez /validateroute %s pour le detail.",
                                tostring(route_template and route_template.route and route_template.route.key or route_key)
                            )
                        )
                        return
                    end

                    Chat.SendMessage(player, "Route indisponible.")
                    return
                end

                Chat.SendMessage(
                    player,
                    string.format(
                        "Route %s active=%s.",
                        tostring(route_template.key),
                        tostring(route_template.is_active == true)
                    )
                )
            end)

            return false
        end

        if command_name == "forcerouteactive" then
            if payload == nil then
                Chat.SendMessage(player, "Usage : /forcerouteactive <route_key> <true|false>")
                return false
            end

            local route_key, active_text = payload:match("^(%S+)%s+(%S+)$")

            if route_key == nil or active_text == nil then
                Chat.SendMessage(player, "Usage : /forcerouteactive <route_key> <true|false>")
                return false
            end

            GRContracts.Server.Service:ForceSetRouteActive(route_key, active_text, function(is_success, route_template, error)
                if not is_success then
                    if error == "route-not-found" or error == "invalid-route-key" then
                        Chat.SendMessage(player, "Route introuvable.")
                        return
                    end

                    if error == "invalid-active-value" then
                        Chat.SendMessage(player, "Valeur active invalide.")
                        return
                    end

                    Chat.SendMessage(player, "Route indisponible.")
                    return
                end

                Chat.SendMessage(
                    player,
                    string.format(
                        "Route %s active=%s force=true.",
                        tostring(route_template.key),
                        tostring(route_template.is_active == true)
                    )
                )
            end)

            return false
        end

        if command_name == "setroutedeadline" then
            if payload == nil then
                Chat.SendMessage(player, "Usage : /setroutedeadline <route_key> <seconds|none>")
                return false
            end

            local route_key, deadline_text = payload:match("^(%S+)%s+(%S+)$")

            if route_key == nil or deadline_text == nil then
                Chat.SendMessage(player, "Usage : /setroutedeadline <route_key> <seconds|none>")
                return false
            end

            GRContracts.Server.Service:SetRouteDeadline(route_key, deadline_text, function(is_success, route_template, error)
                if not is_success then
                    if error == "route-not-found" or error == "invalid-route-key" then
                        Chat.SendMessage(player, "Route introuvable.")
                        return
                    end

                    if error == "invalid-deadline" then
                        Chat.SendMessage(player, "Deadline invalide.")
                        return
                    end

                    Chat.SendMessage(player, "Route indisponible.")
                    return
                end

                if route_template.deadline_seconds == nil then
                    Chat.SendMessage(player, string.format("Route %s deadline=aucune.", tostring(route_template.key)))
                    return
                end

                Chat.SendMessage(
                    player,
                    string.format(
                        "Route %s deadline=%ss.",
                        tostring(route_template.key),
                        tostring(route_template.deadline_seconds)
                    )
                )
            end)

            return false
        end

        if command_name == "setroutereward" then
            if payload == nil then
                Chat.SendMessage(player, "Usage : /setroutereward <route_key> <reward_money> [reward_skill_xp]")
                return false
            end

            local route_key, reward_money_text, reward_skill_xp_text = payload:match("^(%S+)%s+(%S+)%s*(.*)$")
            local reward_skill_xp = trim_string(reward_skill_xp_text)

            if route_key == nil or reward_money_text == nil then
                Chat.SendMessage(player, "Usage : /setroutereward <route_key> <reward_money> [reward_skill_xp]")
                return false
            end

            GRContracts.Server.Service:SetRouteReward(route_key, reward_money_text, reward_skill_xp, function(is_success, route_template, error)
                if not is_success then
                    if error == "route-not-found" or error == "invalid-route-key" then
                        Chat.SendMessage(player, "Route introuvable.")
                        return
                    end

                    if error == "invalid-reward" then
                        Chat.SendMessage(player, "Reward invalide.")
                        return
                    end

                    Chat.SendMessage(player, "Route indisponible.")
                    return
                end

                Chat.SendMessage(
                    player,
                    string.format(
                        "Route %s reward=%s xp=%s.",
                        tostring(route_template.key),
                        tostring(route_template.reward_money or 0),
                        tostring(route_template.reward_skill_xp or 0)
                    )
                )
            end)

            return false
        end

        if command_name == "setrouterequirement" then
            if payload == nil then
                Chat.SendMessage(player, "Usage : /setrouterequirement <route_key> <skill_key|none> <level>")
                return false
            end

            local route_key, skill_key, level_text = payload:match("^(%S+)%s+(%S+)%s+(%S+)$")

            if route_key == nil or skill_key == nil or level_text == nil then
                Chat.SendMessage(player, "Usage : /setrouterequirement <route_key> <skill_key|none> <level>")
                return false
            end

            GRContracts.Server.Service:SetRouteRequirement(route_key, skill_key, level_text, function(is_success, route_template, error)
                if not is_success then
                    if error == "route-not-found" or error == "invalid-route-key" then
                        Chat.SendMessage(player, "Route introuvable.")
                        return
                    end

                    if error == "invalid-requirement" then
                        Chat.SendMessage(player, "Prerequis invalide.")
                        return
                    end

                    Chat.SendMessage(player, "Route indisponible.")
                    return
                end

                if trim_string(route_template.required_skill_key) == nil or (normalize_non_negative_integer(route_template.required_skill_level) or 0) < 1 then
                    Chat.SendMessage(player, string.format("Route %s prerequis skill=aucun.", tostring(route_template.key)))
                    return
                end

                Chat.SendMessage(
                    player,
                    string.format(
                        "Route %s prerequis skill=%s level=%s.",
                        tostring(route_template.key),
                        tostring(route_template.required_skill_key),
                        tostring(route_template.required_skill_level or 0)
                    )
                )
            end)

            return false
        end

        if command_name == "contractrouteinfo" then
            if payload == nil then
                Chat.SendMessage(player, "Usage : /contractrouteinfo <route_key>")
                return false
            end

            GRContracts.Server.Service:GetRouteTemplate(payload, function(is_success, route_template, error)
                if not is_success then
                    Chat.SendMessage(player, "Route transport introuvable.")
                    return
                end

                Chat.SendMessage(player, string.format("Route %s :", tostring(route_template.key)))
                Chat.SendMessage(player, build_route_template_info_line(route_template))
                Chat.SendMessage(
                    player,
                    string.format(
                        "prerequis=%s",
                        tostring(build_route_requirements_message(route_template))
                    )
                )
                Chat.SendMessage(player, string.format("description=%s", tostring(route_template.description or "")))
            end)

            return false
        end

        if command_name == "jobinfo" then
            if payload == nil then
                Chat.SendMessage(player, "Usage : /jobinfo <route_key>")
                return false
            end

            GRContracts.Server.Service:GetJobBoardRoute(payload, function(is_success, route_template, error)
                if not is_success then
                    if error == "route-not-found" then
                        Chat.SendMessage(player, "Mission introuvable.")
                        return
                    end

                    Chat.SendMessage(player, "Mission introuvable.")
                    return
                end

                if route_template.is_active ~= true then
                    Chat.SendMessage(player, "Mission inactive.")
                    return
                end

                Chat.SendMessage(player, string.format("Mission %s :", tostring(route_template.key)))
                Chat.SendMessage(player, build_route_template_info_line(route_template))
                Chat.SendMessage(
                    player,
                    string.format(
                        "prerequis=%s",
                        tostring(build_route_requirements_message(route_template))
                    )
                )
                Chat.SendMessage(player, string.format("description=%s", tostring(route_template.description or "")))
            end)

            return false
        end

        if command_name == "jobrequirements" then
            if payload == nil then
                Chat.SendMessage(player, "Usage : /jobrequirements <route_key>")
                return false
            end

            GRContracts.Server.Service:GetJobRequirements(active_character_id, payload, function(is_success, requirements_result, error)
                local route_template = type(requirements_result) == "table" and (requirements_result.route_template or requirements_result) or nil
                local route_key = trim_string(route_template and route_template.key) or trim_string(payload) or "inconnue"

                if error == "route-not-found" or route_template == nil then
                    Chat.SendMessage(player, "Mission introuvable.")
                    return
                end

                if error == "route-inactive" then
                    Chat.SendMessage(player, "Mission inactive.")
                    return
                end

                Chat.SendMessage(
                    player,
                    string.format(
                        "Prerequis mission %s : %s",
                        tostring(route_key),
                        tostring(build_route_requirements_message(route_template))
                    )
                )

                if is_success then
                    Chat.SendMessage(player, string.format("Prerequis mission %s : OK.", tostring(route_key)))
                    return
                end

                if error == "requirements-not-met" then
                    Chat.SendMessage(player, build_job_requirements_status_line(route_key, requirements_result))
                    return
                end

                if error == "skill-service-unavailable" then
                    Chat.SendMessage(player, string.format("Prerequis mission %s : skill indisponible.", tostring(route_key)))
                    return
                end

                if error == "reputation-service-unavailable" then
                    Chat.SendMessage(player, string.format("Prerequis mission %s : reputation indisponible.", tostring(route_key)))
                    return
                end

                Chat.SendMessage(player, string.format("Prerequis mission %s : verification indisponible.", tostring(route_key)))
            end)

            return false
        end

        if command_name == "contractdeadline" then
            if payload == nil then
                Chat.SendMessage(player, "Usage : /contractdeadline <contract_id>")
                return false
            end

            local contract_id = normalize_positive_integer(payload)

            if contract_id == nil then
                Chat.SendMessage(player, "Contrat introuvable.")
                return false
            end

            GRContracts.Server.Service:GetContractDeadline(active_character_id, contract_id, function(is_success, contract_row, error)
                if not is_success then
                    Chat.SendMessage(player, "Contrat introuvable.")
                    return
                end

                if contract_row.deadline_seconds == nil or contract_row.expires_at == nil then
                    Chat.SendMessage(player, string.format("Deadline contrat #%s : aucune deadline.", tostring(contract_row.id)))
                    return
                end

                Chat.SendMessage(
                    player,
                    string.format(
                        "Deadline contrat #%s : expires_at=%s status=%s.",
                        tostring(contract_row.id),
                        tostring(contract_row.expires_at),
                        tostring(contract_row.status)
                    )
                )
            end)

            return false
        end

        if command_name == "contractrewards" then
            if payload == nil then
                Chat.SendMessage(player, "Usage : /contractrewards <contract_id>")
                return false
            end

            local contract_id = normalize_positive_integer(payload)

            if contract_id == nil then
                Chat.SendMessage(player, "Contrat introuvable.")
                return false
            end

            GRContracts.Server.Service:GetContractRewards(active_character_id, contract_id, function(is_success, contract_row, error)
                if not is_success then
                    Chat.SendMessage(player, "Contrat introuvable.")
                    return
                end

                Chat.SendMessage(player, build_contract_rewards_line(contract_row))
            end)

            return false
        end

        if command_name == "expirecontracts" then
            GRContracts.Server.Service:ExpireContracts(function(is_success, summary, error)
                if not is_success then
                    Chat.SendMessage(player, "Impossible d'expirer les contrats.")
                    return
                end

                Chat.SendMessage(
                    player,
                    string.format(
                        "Expiration contrats : %s contrat(s) expire(s), cargo nettoye=%s, cargo en echec=%s.",
                        tostring((summary and summary.expired_count) or 0),
                        tostring((summary and summary.cleanup_cleaned_count) or 0),
                        tostring((summary and summary.cleanup_failed_count) or 0)
                    )
                )
            end)

            return false
        end

        if command_name == "expiredcontracts" then
            GRContracts.Server.Service:ListExpiredContracts(function(is_success, contract_rows, error)
                if not is_success then
                    Chat.SendMessage(player, "Contrats expires indisponibles.")
                    return
                end

                if type(contract_rows) ~= "table" or #contract_rows == 0 then
                    Chat.SendMessage(player, "Aucun contrat expire.")
                    return
                end

                Chat.SendMessage(player, "Contrats expires :")

                for _, contract_row in ipairs(contract_rows) do
                    Chat.SendMessage(player, build_expired_contract_line(contract_row))
                end
            end)

            return false
        end

        if command_name == "deliverylocations" then
            GRContracts.Server.Service:ListDeliveryLocations(function(is_success, delivery_locations, error)
                if not is_success then
                    Chat.SendMessage(player, "Points de livraison indisponibles.")
                    return
                end

                if type(delivery_locations) ~= "table" or #delivery_locations == 0 then
                    Chat.SendMessage(player, "Aucun point de livraison.")
                    return
                end

                Chat.SendMessage(player, "Points de livraison :")

                for _, delivery_location in ipairs(delivery_locations) do
                    Chat.SendMessage(
                        player,
                        string.format(
                            "- %s radius=%s active=%s",
                            tostring(delivery_location.key),
                            tostring(delivery_location.radius),
                            tostring(delivery_location.is_active)
                        )
                    )
                end
            end)

            return false
        end

        if command_name == "allcontractlocations" then
            GRContracts.Server.Service:ListAllContractLocations(function(is_success, delivery_locations, error)
                if not is_success then
                    Chat.SendMessage(player, "Locations contrats indisponibles.")
                    return
                end

                if type(delivery_locations) ~= "table" or #delivery_locations == 0 then
                    Chat.SendMessage(player, "Aucune location contrat.")
                    return
                end

                Chat.SendMessage(player, "Locations contrats :")

                for _, delivery_location in ipairs(delivery_locations) do
                    Chat.SendMessage(player, build_contract_location_admin_line(delivery_location))
                end
            end)

            return false
        end

        if command_name == "contractlocationroutes" then
            if payload == nil then
                Chat.SendMessage(player, "Usage : /contractlocationroutes <location_key>")
                return false
            end

            GRContracts.Server.Service:GetContractLocationRoutes(payload, function(is_success, location_routes_result, error)
                local delivery_location = location_routes_result and location_routes_result.location or nil
                local route_rows = location_routes_result and location_routes_result.routes or nil

                if not is_success or delivery_location == nil then
                    Chat.SendMessage(player, "Location introuvable.")
                    return
                end

                if type(route_rows) ~= "table" or #route_rows == 0 then
                    Chat.SendMessage(player, string.format("Aucune route n'utilise la location %s.", tostring(delivery_location.key)))
                    return
                end

                Chat.SendMessage(player, string.format("Routes utilisant %s :", tostring(delivery_location.key)))

                for _, route_usage_row in ipairs(route_rows) do
                    Chat.SendMessage(player, build_contract_location_usage_line(route_usage_row))
                end
            end)

            return false
        end

        if command_name == "contractlocationhealth" then
            if payload == nil then
                Chat.SendMessage(player, "Usage : /contractlocationhealth <location_key>")
                return false
            end

            GRContracts.Server.Service:GetContractLocationHealth(payload, function(is_success, location_health, error)
                local delivery_location = location_health and location_health.location or nil
                local impacted_routes = location_health and location_health.impacted_routes or nil

                if not is_success or delivery_location == nil then
                    Chat.SendMessage(player, "Location introuvable.")
                    return
                end

                Chat.SendMessage(
                    player,
                    string.format("Location %s : %s.", tostring(delivery_location.key), tostring(location_health.status or "WARNING"))
                )
                Chat.SendMessage(player, build_contract_location_health_summary_line(location_health))

                if type(location_health.issues) == "table" and #location_health.issues > 0 then
                    Chat.SendMessage(player, "Issues :")

                    for _, issue_text in ipairs(location_health.issues) do
                        Chat.SendMessage(player, string.format("- %s", tostring(issue_text)))
                    end
                end

                if type(impacted_routes) == "table" and #impacted_routes > 0 then
                    Chat.SendMessage(player, "Routes impactees :")

                    for _, route_usage_row in ipairs(impacted_routes) do
                        Chat.SendMessage(player, build_contract_location_impacted_route_line(route_usage_row))
                    end
                end
            end)

            return false
        end

        if command_name == "unusedcontractlocations" then
            GRContracts.Server.Service:ListUnusedContractLocations(function(is_success, delivery_locations, error)
                if not is_success then
                    Chat.SendMessage(player, "Locations inutilisees indisponibles.")
                    return
                end

                if type(delivery_locations) ~= "table" or #delivery_locations == 0 then
                    Chat.SendMessage(player, "Aucune location inutilisee detectee.")
                    return
                end

                Chat.SendMessage(player, "Locations inutilisees :")

                for _, delivery_location in ipairs(delivery_locations) do
                    Chat.SendMessage(player, build_unused_contract_location_line(delivery_location))
                end
            end)

            return false
        end

        if command_name == "createhaulfromroute" then
            if payload == nil then
                Chat.SendMessage(player, "Usage : /createhaulfromroute <route_key>")
                return false
            end

            GRContracts.Server.Service:CreateHaulContractFromRoute(active_character_id, payload, function(is_success, contract_row, error)
                if not is_success then
                    if error == "route-not-found" then
                        Chat.SendMessage(player, "Route transport introuvable.")
                        return
                    end

                    if error == "route-inactive" then
                        Chat.SendMessage(player, "Route transport inactive.")
                        return
                    end

                    if error == "pickup-location-not-found" or error == "pickup-location-key-invalid" then
                        Chat.SendMessage(player, "Point de recuperation introuvable.")
                        return
                    end

                    if error == "pickup-location-inactive" then
                        Chat.SendMessage(player, "Point de recuperation inactif.")
                        return
                    end

                    if error == "delivery-location-not-found" or error == "delivery-location-key-invalid" then
                        Chat.SendMessage(player, "Point de livraison introuvable.")
                        return
                    end

                    if error == "delivery-location-inactive" then
                        Chat.SendMessage(player, "Point de livraison inactif.")
                        return
                    end

                    Chat.SendMessage(player, "Impossible de creer le contrat depuis la route.")
                    return
                end

                Chat.SendMessage(
                    player,
                    string.format(
                        "Contrat transport cree depuis route : #%s route=%s %s reward=%s.",
                        tostring(contract_row.id),
                        tostring(contract_row.route_key or "inconnue"),
                        tostring(format_contract_item_requirement(contract_row)),
                        tostring(contract_row.reward_money)
                    )
                )
            end)

            return false
        end

        if command_name == "takejob" then
            if payload == nil then
                Chat.SendMessage(player, "Usage : /takejob <route_key>")
                return false
            end

            GRContracts.Server.Service:TakeJobFromRoute(active_character_id, payload, function(is_success, contract_row, error)
                if not is_success then
                    if error == "route-not-found" then
                        Chat.SendMessage(player, "Mission introuvable.")
                        return
                    end

                    if error == "route-inactive" then
                        Chat.SendMessage(player, "Mission inactive.")
                        return
                    end

                    if error == "active-job-limit-reached" then
                        Chat.SendMessage(player, "Limite de missions actives atteinte.")
                        return
                    end

                    if error == "requirements-not-met" then
                        Chat.SendMessage(player, "Mission impossible : prerequis non remplis.")
                        return
                    end

                    if error == "skill-service-unavailable" or error == "reputation-service-unavailable" then
                        Chat.SendMessage(player, "Mission impossible : prerequis indisponibles.")
                        return
                    end

                    if error == "contract-assign-failed" then
                        Chat.SendMessage(player, "Impossible d'assigner la mission.")
                        return
                    end

                    if error == "pickup-location-not-found"
                        or error == "pickup-location-key-invalid"
                        or error == "pickup-location-inactive"
                        or error == "delivery-location-not-found"
                        or error == "delivery-location-key-invalid"
                        or error == "delivery-location-inactive"
                        or error == "contract-create-failed"
                    then
                        Chat.SendMessage(player, "Impossible de creer la mission.")
                        return
                    end

                    Chat.SendMessage(player, "Impossible de creer la mission.")
                    return
                end

                Chat.SendMessage(
                    player,
                    string.format(
                        "Mission acceptee : contrat #%s route=%s pickup=%s destination=%s.",
                        tostring(contract_row.id),
                        tostring(contract_row.source_route_key or contract_row.route_key or "inconnue"),
                        tostring(contract_row.pickup_location_key or "aucun"),
                        tostring(contract_row.delivery_location_key or "aucune")
                    )
                )
            end)

            return false
        end

        if command_name == "deliverylocationinfo" then
            if payload == nil then
                Chat.SendMessage(player, "Usage : /deliverylocationinfo <location_key>")
                return false
            end

            GRContracts.Server.Service:GetDeliveryLocationInfo(payload, function(is_success, delivery_location, error)
                if not is_success then
                    if error == "location-not-found" or error == "delivery-location-key-required" then
                        Chat.SendMessage(player, "Point de livraison introuvable.")
                        return
                    end

                    Chat.SendMessage(player, "Point de livraison introuvable.")
                    return
                end

                Chat.SendMessage(player, build_delivery_location_info_line(delivery_location))
            end)

            return false
        end

        if command_name == "createcontractlocation" then
            if payload == nil then
                Chat.SendMessage(player, "Usage : /createcontractlocation <location_key> <radius> <name>")
                return false
            end

            local location_key, radius_text, name = payload:match("^(%S+)%s+(%S+)%s+(.+)$")

            if location_key == nil then
                Chat.SendMessage(player, "Usage : /createcontractlocation <location_key> <radius> <name>")
                return false
            end

            GRContracts.Server.Service:CreateContractLocation(location_key, radius_text, name, function(is_success, delivery_location, error)
                if not is_success then
                    if error == "invalid-location-key" then
                        Chat.SendMessage(player, "Creation location impossible : location_key invalide.")
                        return
                    end

                    if error == "location-already-exists" then
                        Chat.SendMessage(player, "Creation location impossible : location deja existante.")
                        return
                    end

                    if error == "invalid-radius" then
                        Chat.SendMessage(player, "Creation location impossible : radius invalide.")
                        return
                    end

                    if error == "invalid-name" then
                        Chat.SendMessage(player, "Creation location impossible : nom invalide.")
                        return
                    end

                    Chat.SendMessage(player, "Creation location impossible.")
                    return
                end

                Chat.SendMessage(
                    player,
                    string.format(
                        "Location creee : %s radius=%s active=%s calibrated=false.",
                        tostring(delivery_location.key),
                        tostring(format_radius_value(delivery_location.radius)),
                        tostring(delivery_location.is_active == true)
                    )
                )
            end)

            return false
        end

        if command_name == "setcontractlocationactive" then
            if payload == nil then
                Chat.SendMessage(player, "Usage : /setcontractlocationactive <location_key> <true|false>")
                return false
            end

            local location_key, active_text = payload:match("^(%S+)%s+(%S+)$")

            if location_key == nil then
                Chat.SendMessage(player, "Usage : /setcontractlocationactive <location_key> <true|false>")
                return false
            end

            GRContracts.Server.Service:SetContractLocationActive(location_key, active_text, function(is_success, delivery_location, error)
                if not is_success then
                    if error == "invalid-active-value" then
                        Chat.SendMessage(player, "Valeur active invalide.")
                        return
                    end

                    if error == "location-not-found" then
                        Chat.SendMessage(player, "Location introuvable.")
                        return
                    end

                    Chat.SendMessage(player, "Impossible de mettre a jour la location.")
                    return
                end

                Chat.SendMessage(
                    player,
                    string.format("Location %s active=%s.", tostring(delivery_location.key), tostring(delivery_location.is_active == true))
                )
            end)

            return false
        end

        if command_name == "setcontractlocationradius" then
            if payload == nil then
                Chat.SendMessage(player, "Usage : /setcontractlocationradius <location_key> <radius>")
                return false
            end

            local location_key, radius_text = payload:match("^(%S+)%s+(%S+)$")

            if location_key == nil then
                Chat.SendMessage(player, "Usage : /setcontractlocationradius <location_key> <radius>")
                return false
            end

            GRContracts.Server.Service:SetContractLocationRadius(location_key, radius_text, function(is_success, delivery_location, error)
                if not is_success then
                    if error == "invalid-radius" then
                        Chat.SendMessage(player, "Radius invalide.")
                        return
                    end

                    if error == "location-not-found" then
                        Chat.SendMessage(player, "Location introuvable.")
                        return
                    end

                    Chat.SendMessage(player, "Impossible de mettre a jour la location.")
                    return
                end

                Chat.SendMessage(
                    player,
                    string.format("Location %s radius=%s.", tostring(delivery_location.key), tostring(format_radius_value(delivery_location.radius)))
                )
            end)

            return false
        end

        if command_name == "setcontractlocationname" then
            if payload == nil then
                Chat.SendMessage(player, "Usage : /setcontractlocationname <location_key> <name>")
                return false
            end

            local location_key, name = payload:match("^(%S+)%s+(.+)$")

            if location_key == nil then
                Chat.SendMessage(player, "Usage : /setcontractlocationname <location_key> <name>")
                return false
            end

            GRContracts.Server.Service:SetContractLocationName(location_key, name, function(is_success, delivery_location, error)
                if not is_success then
                    if error == "invalid-name" then
                        Chat.SendMessage(player, "Nom invalide.")
                        return
                    end

                    if error == "location-not-found" then
                        Chat.SendMessage(player, "Location introuvable.")
                        return
                    end

                    Chat.SendMessage(player, "Impossible de mettre a jour la location.")
                    return
                end

                Chat.SendMessage(player, string.format("Location %s nom mis a jour.", tostring(delivery_location.key)))
            end)

            return false
        end

        if command_name == "setdeliverylocationhere" then
            if payload == nil then
                Chat.SendMessage(player, "Usage : /setdeliverylocationhere <location_key> [radius]")
                return false
            end

            local location_key, radius_text = payload:match("^(%S+)%s*(.*)$")

            if location_key == nil then
                Chat.SendMessage(player, "Usage : /setdeliverylocationhere <location_key> [radius]")
                return false
            end

            if trim_string(radius_text) == nil then
                radius_text = nil
            end

            GRContracts.Server.Service:SetDeliveryLocationHere(player, location_key, radius_text, function(is_success, delivery_location, error)
                if not is_success then
                    if error == "location-not-found" or error == "delivery-location-key-required" then
                        Chat.SendMessage(player, "Point de livraison introuvable.")
                        return
                    end

                    if error == "location-inactive" then
                        Chat.SendMessage(player, "Point de livraison inactif.")
                        return
                    end

                    if error == "player-position-unavailable" then
                        Chat.SendMessage(player, "Position joueur indisponible.")
                        return
                    end

                    if error == "invalid-radius" or error == "delivery-location-radius-invalid" then
                        Chat.SendMessage(player, "Radius invalide.")
                        return
                    end

                    Chat.SendMessage(player, "Impossible de mettre a jour le point de livraison.")
                    return
                end

                Chat.SendMessage(
                    player,
                    string.format(
                        "Point de livraison mis a jour : %s x=%s y=%s z=%s radius=%s.",
                        tostring(delivery_location.key),
                        tostring(format_coordinate_value(delivery_location.position_x)),
                        tostring(format_coordinate_value(delivery_location.position_y)),
                        tostring(format_coordinate_value(delivery_location.position_z)),
                        tostring(format_radius_value(delivery_location.radius))
                    )
                )
            end)

            return false
        end

        if command_name == "mycontracts" then
            GRContracts.Server.Service:ListMyContracts(active_character_id, function(is_success, contract_rows, error)
                if not is_success then
                    Chat.SendMessage(player, "Mes contrats sont indisponibles.")
                    return
                end

                if type(contract_rows) ~= "table" or #contract_rows == 0 then
                    Chat.SendMessage(player, "Aucun contrat.")
                    return
                end

                Chat.SendMessage(player, "Mes contrats :")

                for _, contract_row in ipairs(contract_rows) do
                    Chat.SendMessage(player, build_my_contract_line(contract_row))
                end
            end)

            return false
        end

        if command_name == "createcontract" then
            if payload == nil then
                Chat.SendMessage(player, "Usage : /createcontract <type> <reward_money> <description>")
                return false
            end

            local contract_type, reward_money_text, description = payload:match("^(%S+)%s+([+-]?%d+)%s+(.+)$")

            if contract_type == nil then
                Chat.SendMessage(player, "Usage : /createcontract <type> <reward_money> <description>")
                return false
            end

            GRContracts.Server.Service:CreateContract(active_character_id, contract_type, reward_money_text, description, function(is_success, contract_row, error)
                if not is_success then
                    if error == "contract-type-invalid" then
                        Chat.SendMessage(player, "Type de contrat invalide.")
                        return
                    end

                    if error == "reward-money-invalid" then
                        Chat.SendMessage(player, "Montant invalide.")
                        return
                    end

                    if error == "description-invalid" then
                        Chat.SendMessage(player, "Description invalide.")
                        return
                    end

                    Chat.SendMessage(player, "Impossible de creer le contrat.")
                    return
                end

                Chat.SendMessage(
                    player,
                    string.format(
                        "Contrat cree : #%s %s reward=%s",
                        tostring(contract_row.id),
                        tostring(contract_row.type),
                        tostring(contract_row.reward_money)
                    )
                )
            end)

            return false
        end

        if command_name == "createdeliverycontract" then
            if payload == nil then
                Chat.SendMessage(player, "Usage : /createdeliverycontract <item_key> <quantity> <reward_money> <description>")
                return false
            end

            local item_key, quantity_text, reward_money_text, description = payload:match("^(%S+)%s+(%S+)%s+([+-]?%d+)%s+(.+)$")

            if item_key == nil then
                Chat.SendMessage(player, "Usage : /createdeliverycontract <item_key> <quantity> <reward_money> <description>")
                return false
            end

            GRContracts.Server.Service:CreateDeliveryContract(
                active_character_id,
                item_key,
                quantity_text,
                reward_money_text,
                description,
                function(is_success, contract_row, error)
                    if not is_success then
                        if error == "item-key-invalid" then
                            Chat.SendMessage(player, "Item requis invalide.")
                            return
                        end

                        if error == "quantity-invalid" then
                            Chat.SendMessage(player, "Quantite invalide.")
                            return
                        end

                        if error == "reward-money-invalid" then
                            Chat.SendMessage(player, "Montant invalide.")
                            return
                        end

                        if error == "description-invalid" then
                            Chat.SendMessage(player, "Description invalide.")
                            return
                        end

                        Chat.SendMessage(player, "Impossible de creer le contrat de livraison.")
                        return
                    end

                    Chat.SendMessage(
                        player,
                        string.format(
                            "Contrat cree : #%s delivery reward=%s %s",
                            tostring(contract_row.id),
                            tostring(contract_row.reward_money),
                            tostring(format_contract_item_requirement(contract_row))
                        )
                    )
                end
            )

            return false
        end

        if command_name == "createdeliverycontractat" then
            if payload == nil then
                Chat.SendMessage(player, "Usage : /createdeliverycontractat <item_key> <quantity> <reward_money> <location_key> <description>")
                return false
            end

            local item_key, quantity_text, reward_money_text, location_key, description = payload:match("^(%S+)%s+(%S+)%s+([+-]?%d+)%s+(%S+)%s+(.+)$")

            if item_key == nil then
                Chat.SendMessage(player, "Usage : /createdeliverycontractat <item_key> <quantity> <reward_money> <location_key> <description>")
                return false
            end

            GRContracts.Server.Service:CreateDeliveryContractAt(
                active_character_id,
                item_key,
                quantity_text,
                reward_money_text,
                location_key,
                description,
                function(is_success, contract_row, error)
                    if not is_success then
                        if error == "item-key-invalid" then
                            Chat.SendMessage(player, "Item requis invalide.")
                            return
                        end

                        if error == "quantity-invalid" then
                            Chat.SendMessage(player, "Quantite invalide.")
                            return
                        end

                        if error == "reward-money-invalid" then
                            Chat.SendMessage(player, "Montant invalide.")
                            return
                        end

                        if error == "delivery-location-key-invalid" or error == "delivery-location-not-found" then
                            Chat.SendMessage(player, "Point de livraison introuvable.")
                            return
                        end

                        if error == "delivery-location-inactive" then
                            Chat.SendMessage(player, "Point de livraison inactif.")
                            return
                        end

                        if error == "description-invalid" then
                            Chat.SendMessage(player, "Description invalide.")
                            return
                        end

                        Chat.SendMessage(player, "Impossible de creer le contrat de livraison.")
                        return
                    end

                    Chat.SendMessage(
                        player,
                        string.format(
                            "Contrat livraison cree : #%s %s reward=%s destination=%s.",
                            tostring(contract_row.id),
                            tostring(format_contract_item_requirement(contract_row)),
                            tostring(contract_row.reward_money),
                            tostring(contract_row.delivery_location_key or "aucune")
                        )
                    )
                end
            )

            return false
        end

        if command_name == "createhaulcontract" then
            if payload == nil then
                Chat.SendMessage(player, "Usage : /createhaulcontract <item_key> <quantity> <reward_money> <pickup_location_key> <delivery_location_key> <description>")
                return false
            end

            local item_key, quantity_text, reward_money_text, pickup_location_key, delivery_location_key, description =
                payload:match("^(%S+)%s+(%S+)%s+([+-]?%d+)%s+(%S+)%s+(%S+)%s+(.+)$")

            if item_key == nil then
                Chat.SendMessage(player, "Usage : /createhaulcontract <item_key> <quantity> <reward_money> <pickup_location_key> <delivery_location_key> <description>")
                return false
            end

            GRContracts.Server.Service:CreateHaulContract(
                active_character_id,
                item_key,
                quantity_text,
                reward_money_text,
                pickup_location_key,
                delivery_location_key,
                description,
                function(is_success, contract_row, error)
                    if not is_success then
                        if error == "item-key-invalid" then
                            Chat.SendMessage(player, "Item requis invalide.")
                            return
                        end

                        if error == "quantity-invalid" then
                            Chat.SendMessage(player, "Quantite invalide.")
                            return
                        end

                        if error == "reward-money-invalid" then
                            Chat.SendMessage(player, "Montant invalide.")
                            return
                        end

                        if error == "pickup-location-key-invalid" or error == "pickup-location-not-found" then
                            Chat.SendMessage(player, "Point de recuperation introuvable.")
                            return
                        end

                        if error == "pickup-location-inactive" then
                            Chat.SendMessage(player, "Point de recuperation inactif.")
                            return
                        end

                        if error == "delivery-location-key-invalid" or error == "delivery-location-not-found" then
                            Chat.SendMessage(player, "Point de livraison introuvable.")
                            return
                        end

                        if error == "delivery-location-inactive" then
                            Chat.SendMessage(player, "Point de livraison inactif.")
                            return
                        end

                        if error == "description-invalid" then
                            Chat.SendMessage(player, "Description invalide.")
                            return
                        end

                        Chat.SendMessage(player, "Impossible de creer le contrat transport.")
                        return
                    end

                    Chat.SendMessage(
                        player,
                        string.format(
                            "Contrat transport cree : #%s %s reward=%s pickup=%s destination=%s.",
                            tostring(contract_row.id),
                            tostring(format_contract_item_requirement(contract_row)),
                            tostring(contract_row.reward_money),
                            tostring(contract_row.pickup_location_key or "aucun"),
                            tostring(contract_row.delivery_location_key or "aucune")
                        )
                    )
                end
            )

            return false
        end

        if payload == nil then
            if command_name == "acceptcontract" then
                Chat.SendMessage(player, "Usage : /acceptcontract <contract_id>")
            elseif command_name == "pickupcontract" then
                Chat.SendMessage(player, "Usage : /pickupcontract <contract_id>")
            elseif command_name == "abandoncontract" then
                Chat.SendMessage(player, "Usage : /abandoncontract <contract_id>")
            elseif command_name == "contractdeadline" then
                Chat.SendMessage(player, "Usage : /contractdeadline <contract_id>")
            elseif command_name == "contractrewards" then
                Chat.SendMessage(player, "Usage : /contractrewards <contract_id>")
            elseif command_name == "grantcontractrewards" then
                Chat.SendMessage(player, "Usage : /grantcontractrewards <contract_id>")
            elseif command_name == "cleanupcontractcargo" then
                Chat.SendMessage(player, "Usage : /cleanupcontractcargo <contract_id>")
            elseif command_name == "completecontract" then
                Chat.SendMessage(player, "Usage : /completecontract <contract_id>")
            else
                Chat.SendMessage(player, "Usage : /cancelcontract <contract_id> [reason]")
            end

            return false
        end

        if command_name == "cancelcontract" then
            local contract_id_text, cancel_reason = payload:match("^(%S+)%s*(.*)$")
            local contract_id = normalize_positive_integer(contract_id_text)

            if contract_id == nil then
                Chat.SendMessage(player, "Annulation impossible : contrat introuvable.")
                return false
            end

            if trim_string(cancel_reason) == nil then
                cancel_reason = nil
            end

            GRContracts.Server.Service:CancelContract(active_character_id, contract_id, cancel_reason, function(is_success, contract_row, error)
                if not is_success then
                    if error == "contract-not-found" then
                        Chat.SendMessage(player, "Annulation impossible : contrat introuvable.")
                        return
                    end

                    if error == "contract-terminal" then
                        Chat.SendMessage(player, "Annulation impossible : contrat deja termine.")
                        return
                    end

                    Chat.SendMessage(player, "Impossible d'annuler ce contrat.")
                    return
                end

                Chat.SendMessage(
                    player,
                    string.format(
                        "Contrat annule : #%s reason=%s.",
                        tostring(contract_row.id),
                        tostring(contract_row.cancel_reason or cancel_reason or "admin-cancel")
                    )
                )
            end)

            return false
        end

        local contract_id = normalize_positive_integer(payload)

        if contract_id == nil then
            if command_name == "abandoncontract" then
                Chat.SendMessage(player, "Abandon impossible : contrat introuvable.")
                return false
            end

            Chat.SendMessage(player, "Contrat introuvable.")
            return false
        end

        if command_name == "pickupcontract" then
            GRContracts.Server.Service:PickupContract(active_character_id, player, contract_id, function(is_success, contract_row, error)
                if not is_success then
                    if error == "contract-not-found" then
                        Chat.SendMessage(player, "Pickup impossible : contrat introuvable.")
                        return
                    end

                    if error == "contract-expired" then
                        Chat.SendMessage(player, "Pickup impossible : deadline expiree.")
                        return
                    end

                    if error == "pickup-contract-forbidden" then
                        Chat.SendMessage(player, "Pickup impossible : contrat non accepte par vous.")
                        return
                    end

                    if error == "pickup-already-completed" or error == "pickup-not-required" then
                        Chat.SendMessage(player, "Pickup impossible : cargaison deja recuperee.")
                        return
                    end

                    if error == "pickup-location-not-found" then
                        Chat.SendMessage(player, "Pickup impossible : point de recuperation introuvable.")
                        return
                    end

                    if error == "pickup-location-inactive" then
                        Chat.SendMessage(player, "Pickup impossible : point de recuperation inactif.")
                        return
                    end

                    if error == "pickup-location-position-missing" then
                        Chat.SendMessage(player, "Pickup impossible : position point de recuperation manquante.")
                        return
                    end

                    if error == "player-position-unavailable" then
                        Chat.SendMessage(player, "Pickup impossible : position joueur indisponible.")
                        return
                    end

                    if error == "too-far-from-pickup-location" then
                        Chat.SendMessage(player, "Pickup impossible : vous etes trop loin du point de recuperation.")
                        return
                    end

                    if error == "inventory-unavailable" or error == "pickup-item-invalid" then
                        Chat.SendMessage(player, "Pickup impossible : inventaire indisponible.")
                        return
                    end

                    Chat.SendMessage(player, "Pickup impossible.")
                    return
                end

                Chat.SendMessage(
                    player,
                    string.format(
                        "Cargaison recuperee : contrat #%s %s pickup=%s.",
                        tostring(contract_row.id),
                        tostring(format_contract_item_requirement(contract_row)),
                        tostring(contract_row.pickup_location_key or "aucun")
                    )
                )
            end)

            return false
        end

        if command_name == "cleanupcontractcargo" then
            GRContracts.Server.Service:CleanupExpiredContractCargo(contract_id, function(is_success, contract_row, error)
                if not is_success then
                    if error == "contract-not-found" then
                        Chat.SendMessage(player, "Cleanup cargo impossible : contrat introuvable.")
                        return
                    end

                    if error == "contract-not-expired" then
                        Chat.SendMessage(player, "Cleanup cargo impossible : contrat non expire.")
                        return
                    end

                    if error == "cargo-not-picked-up" then
                        Chat.SendMessage(player, "Cleanup cargo impossible : cargaison non recuperee.")
                        return
                    end

                    if error == "inventory-unavailable" then
                        Chat.SendMessage(player, "Cleanup cargo impossible : inventaire indisponible.")
                        return
                    end

                    if error == "items-missing" then
                        Chat.SendMessage(player, "Cleanup cargo impossible : items manquants.")
                        return
                    end

                    Chat.SendMessage(player, "Cleanup cargo impossible.")
                    return
                end

                Chat.SendMessage(
                    player,
                    string.format(
                        "Cleanup cargo effectue : contrat #%s %s.",
                        tostring(contract_row.id),
                        tostring(format_contract_item_requirement(contract_row))
                    )
                )
            end)

            return false
        end

        if command_name == "grantcontractrewards" then
            GRContracts.Server.Service:GrantContractRewards(contract_id, function(is_success, contract_row, error)
                if not is_success then
                    if error == "contract-not-found" then
                        Chat.SendMessage(player, "Contrat introuvable.")
                        return
                    end

                    if error == "contract-not-completed" then
                        Chat.SendMessage(player, "Recompenses impossibles : contrat non termine.")
                        return
                    end

                    if error == "rewards-already-granted" then
                        Chat.SendMessage(player, "Recompenses impossibles : deja accordees.")
                        return
                    end

                    if error == "rewards-not-required" then
                        Chat.SendMessage(player, "Recompenses impossibles : aucune recompense.")
                        return
                    end

                    if error == "skill-service-unavailable" then
                        Chat.SendMessage(player, "Recompenses impossibles : skill indisponible.")
                        return
                    end

                    if error == "reputation-service-unavailable" then
                        Chat.SendMessage(player, "Recompenses impossibles : reputation indisponible.")
                        return
                    end

                    Chat.SendMessage(player, "Recompenses impossibles.")
                    return
                end

                local reward_skill_key = trim_string(contract_row and contract_row.reward_skill_key)
                local reward_skill_xp = normalize_positive_integer(contract_row and contract_row.reward_skill_xp)
                local reward_reputation_key = trim_string(contract_row and contract_row.reward_reputation_key)
                local reward_reputation_delta = tonumber(contract_row and contract_row.reward_reputation_delta) or 0

                if reward_reputation_key ~= nil and reward_reputation_delta ~= 0 then
                    Chat.SendMessage(
                        player,
                        string.format(
                            "Recompenses accordees : contrat #%s skill=%s xp=%s reputation=%s delta=%s.",
                            tostring(contract_row.id),
                            tostring(reward_skill_key or "aucune"),
                            tostring(reward_skill_xp or 0),
                            tostring(reward_reputation_key),
                            tostring(reward_reputation_delta)
                        )
                    )
                    return
                end

                Chat.SendMessage(
                    player,
                    string.format(
                        "Recompenses accordees : contrat #%s skill=%s xp=%s.",
                        tostring(contract_row.id),
                        tostring(reward_skill_key or "aucune"),
                        tostring(reward_skill_xp or 0)
                    )
                )
            end)

            return false
        end

        if command_name == "abandoncontract" then
            GRContracts.Server.Service:AbandonContract(active_character_id, contract_id, function(is_success, contract_row, error)
                if not is_success then
                    if error == "contract-not-found" then
                        Chat.SendMessage(player, "Abandon impossible : contrat introuvable.")
                        return
                    end

                    if error == "not-assigned-to-character" then
                        Chat.SendMessage(player, "Abandon impossible : contrat non assigne a vous.")
                        return
                    end

                    if error == "contract-terminal" then
                        Chat.SendMessage(player, "Abandon impossible : contrat deja termine.")
                        return
                    end

                    if error == "cargo-remove-failed" or error == "inventory-unavailable" then
                        Chat.SendMessage(player, "Abandon impossible : cargaison impossible a retirer.")
                        return
                    end

                    Chat.SendMessage(player, "Abandon impossible.")
                    return
                end

                Chat.SendMessage(player, string.format("Contrat abandonne : #%s.", tostring(contract_row.id)))
            end)

            return false
        end

        if command_name == "acceptcontract" then
            GRContracts.Server.Service:AcceptContract(active_character_id, contract_id, function(is_success, contract_row, error)
                if not is_success then
                    if error == "contract-not-found" then
                        Chat.SendMessage(player, "Contrat introuvable.")
                        return
                    end

                    if error == "contract-not-available" then
                        Chat.SendMessage(player, "Contrat non disponible.")
                        return
                    end

                    Chat.SendMessage(player, "Impossible d'accepter ce contrat.")
                    return
                end

                Chat.SendMessage(player, string.format("Contrat accepte : #%s", tostring(contract_row.id)))
            end)

            return false
        end

        if command_name == "completecontract" then
            GRContracts.Server.Service:CompleteContract(active_character_id, contract_id, player, function(is_success, contract_row, error)
                if not is_success then
                    if error == "contract-not-found" then
                        Chat.SendMessage(player, "Contrat introuvable.")
                        return
                    end

                    if error == "contract-already-completed" then
                        Chat.SendMessage(player, "Contrat deja termine.")
                        return
                    end

                    if error == "contract-complete-forbidden" then
                        Chat.SendMessage(player, "Vous ne pouvez pas terminer ce contrat.")
                        return
                    end

                    if error == "contract-expired" then
                        Chat.SendMessage(player, "Contrat impossible : deadline expiree.")
                        return
                    end

                    if error == "required-item-missing" then
                        Chat.SendMessage(
                            player,
                            string.format(
                                "Contrat impossible : item requis manquant %s x%s.",
                                tostring(contract_row and contract_row.required_item_key or "inconnu"),
                                tostring(contract_row and contract_row.required_item_quantity or "?")
                            )
                        )
                        return
                    end

                    if error == "pickup-not-completed" then
                        Chat.SendMessage(player, "Contrat impossible : cargaison non recuperee.")
                        return
                    end

                    if error == "delivery-location-not-found" then
                        Chat.SendMessage(player, "Contrat impossible : point de livraison introuvable.")
                        return
                    end

                    if error == "delivery-location-inactive" then
                        Chat.SendMessage(player, "Contrat impossible : point de livraison inactif.")
                        return
                    end

                    if error == "delivery-location-position-missing" then
                        Chat.SendMessage(player, "Contrat impossible : position destination manquante.")
                        return
                    end

                    if error == "player-position-unavailable" then
                        Chat.SendMessage(player, "Contrat impossible : position joueur indisponible.")
                        return
                    end

                    if error == "too-far-from-delivery-location" then
                        Chat.SendMessage(player, "Contrat impossible : vous etes trop loin du point de livraison.")
                        return
                    end

                    if error == "inventory-check-unavailable" or error == "inventory-remove-failed" then
                        Chat.SendMessage(player, "Contrat impossible : inventaire indisponible.")
                        return
                    end

                    if error == "payment-failed" or error == "inventory-compensation-failed" then
                        Chat.SendMessage(player, "Contrat impossible : paiement echoue, compensation item tentee.")
                        return
                    end

                    Chat.SendMessage(player, "Impossible de terminer ce contrat.")
                    return
                end

                local payment_status = tostring(contract_row.payment_status or "unavailable")
                local payment_message = "non-disponible"

                if payment_status == "paid" then
                    payment_message = "effectue"
                elseif payment_status == "failed" then
                    payment_message = "echoue"
                elseif payment_status == "pending" then
                    payment_message = "non-disponible"
                end

                Chat.SendMessage(
                    player,
                    string.format(
                        "Contrat termine : #%s pickup=%s livraison=%s %s paiement=%s.",
                        tostring(contract_row.id),
                        tostring(contract_row.pickup_location_key or "aucun"),
                        tostring(contract_row.delivery_location_key or "aucune"),
                        tostring(format_contract_item_requirement(contract_row)),
                        tostring(payment_message)
                    )
                )
            end)

            return false
        end

        return false
    end)
end

Console.Log("[gr_contracts][server] Contracts package loaded.")
Console.Log("[gr_contracts][server] Contracts bridge exported.")

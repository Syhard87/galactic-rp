BEGIN;

WITH ranked_factions AS (
    SELECT
        id,
        type,
        ROW_NUMBER() OVER (
            PARTITION BY type
            ORDER BY
                CASE name
                    WHEN 'Civil' THEN 0
                    WHEN 'Autorité Galactique' THEN 0
                    WHEN 'Corps Militaire' THEN 0
                    WHEN 'Guilde Marchande' THEN 0
                    WHEN 'Syndicat Criminel' THEN 0
                    ELSE 1
                END,
                id
        ) AS row_rank
    FROM factions
    WHERE type IN ('civil', 'government', 'military', 'merchant', 'criminal')
)
DELETE FROM factions AS f
USING ranked_factions AS rf
WHERE f.id = rf.id
  AND rf.row_rank > 1;

UPDATE factions
SET
    name = CASE type
        WHEN 'government' THEN 'Autorité Galactique'
        WHEN 'military' THEN 'Corps Militaire'
        WHEN 'merchant' THEN 'Guilde Marchande'
        WHEN 'criminal' THEN 'Syndicat Criminel'
        WHEN 'civil' THEN 'Civil'
        ELSE name
    END,
    updated_at = NOW()
WHERE type IN ('civil', 'government', 'military', 'merchant', 'criminal');

UPDATE faction_ranks AS fr
SET
    name = CASE
        WHEN f.type = 'civil' AND fr.level = 1 THEN 'Citoyen'
        WHEN f.type = 'government' AND fr.level = 1 THEN 'Agent'
        WHEN f.type = 'government' AND fr.level = 2 THEN 'Officier'
        WHEN f.type = 'government' AND fr.level = 3 THEN 'Gouverneur'
        WHEN f.type = 'military' AND fr.level = 1 THEN 'Recrue'
        WHEN f.type = 'military' AND fr.level = 2 THEN 'Soldat'
        WHEN f.type = 'military' AND fr.level = 3 THEN 'Sergent'
        WHEN f.type = 'military' AND fr.level = 4 THEN 'Commandant'
        WHEN f.type = 'merchant' AND fr.level = 1 THEN 'Transporteur'
        WHEN f.type = 'merchant' AND fr.level = 2 THEN 'Négociant'
        WHEN f.type = 'merchant' AND fr.level = 3 THEN 'Maître de Guilde'
        WHEN f.type = 'criminal' AND fr.level = 1 THEN 'Contact'
        WHEN f.type = 'criminal' AND fr.level = 2 THEN 'Contrebandier'
        WHEN f.type = 'criminal' AND fr.level = 3 THEN 'Lieutenant'
        ELSE fr.name
    END,
    updated_at = NOW()
FROM factions AS f
WHERE fr.faction_id = f.id
  AND f.type IN ('civil', 'government', 'military', 'merchant', 'criminal');

WITH seeded_factions (name, type, description, is_whitelisted) AS (
    VALUES
        ('Civil', 'civil', 'Default civilian affiliation for characters without organizational duties.', FALSE),
        ('Autorité Galactique', 'government', 'Government administration and public authority branch.', TRUE),
        ('Corps Militaire', 'military', 'Military branch responsible for defense and deployment.', TRUE),
        ('Guilde Marchande', 'merchant', 'Commercial network focused on trade and logistics.', FALSE),
        ('Syndicat Criminel', 'criminal', 'Underground criminal network operating in the outer systems.', TRUE)
)
INSERT INTO factions (
    name,
    type,
    description,
    is_whitelisted
)
SELECT
    seeded_factions.name,
    seeded_factions.type,
    seeded_factions.description,
    seeded_factions.is_whitelisted
FROM seeded_factions
ON CONFLICT (name) DO UPDATE
SET
    type = EXCLUDED.type,
    description = EXCLUDED.description,
    is_whitelisted = EXCLUDED.is_whitelisted,
    updated_at = NOW();

WITH seeded_ranks (faction_name, rank_name, level, permissions_json) AS (
    VALUES
        ('Civil', 'Citoyen', 1, '{"can_hold_public_office": false}'),
        ('Autorité Galactique', 'Agent', 1, '{"can_issue_citation": true}'),
        ('Autorité Galactique', 'Officier', 2, '{"can_issue_citation": true, "can_command_patrol": true}'),
        ('Autorité Galactique', 'Gouverneur', 3, '{"can_issue_citation": true, "can_command_patrol": true, "can_manage_district": true}'),
        ('Corps Militaire', 'Recrue', 1, '{"can_carry_standard_rifle": true}'),
        ('Corps Militaire', 'Soldat', 2, '{"can_carry_standard_rifle": true, "can_deploy_field_vehicle": true}'),
        ('Corps Militaire', 'Sergent', 3, '{"can_carry_standard_rifle": true, "can_deploy_field_vehicle": true, "can_lead_fireteam": true}'),
        ('Corps Militaire', 'Commandant', 4, '{"can_carry_standard_rifle": true, "can_deploy_field_vehicle": true, "can_lead_fireteam": true, "can_authorize_operations": true}'),
        ('Guilde Marchande', 'Transporteur', 1, '{"can_access_trade_terminals": true}'),
        ('Guilde Marchande', 'Négociant', 2, '{"can_access_trade_terminals": true, "can_open_contracts": true}'),
        ('Guilde Marchande', 'Maître de Guilde', 3, '{"can_access_trade_terminals": true, "can_open_contracts": true, "can_manage_trade_ledger": true}'),
        ('Syndicat Criminel', 'Contact', 1, '{"can_access_black_market": true}'),
        ('Syndicat Criminel', 'Contrebandier', 2, '{"can_access_black_market": true, "can_move_contraband": true}'),
        ('Syndicat Criminel', 'Lieutenant', 3, '{"can_access_black_market": true, "can_move_contraband": true, "can_run_cell": true}')
)
INSERT INTO faction_ranks (
    faction_id,
    name,
    level,
    permissions_json
)
SELECT
    factions.id,
    seeded_ranks.rank_name,
    seeded_ranks.level,
    seeded_ranks.permissions_json::JSONB
FROM seeded_ranks
INNER JOIN factions
    ON factions.name = seeded_ranks.faction_name
ON CONFLICT (faction_id, level) DO UPDATE
SET
    name = EXCLUDED.name,
    permissions_json = EXCLUDED.permissions_json,
    updated_at = NOW();

COMMIT;

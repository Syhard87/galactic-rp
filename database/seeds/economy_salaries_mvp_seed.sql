BEGIN;

WITH seeded_rules (key, label, faction_key, wallet, amount, cooldown_seconds, is_active) AS (
    VALUES
        ('civil_salary', 'Civil Salary', 'civil', 'bank', 90, 3600, TRUE),
        ('government_salary', 'Government Salary', 'government', 'bank', 150, 3600, TRUE),
        ('military_salary', 'Military Salary', 'military', 'bank', 180, 3600, TRUE),
        ('merchant_salary', 'Merchant Salary', 'merchant', 'bank', 120, 3600, TRUE),
        ('criminal_salary', 'Criminal Salary', 'criminal', 'cash', 80, 3600, TRUE)
)
INSERT INTO economy_salary_rules (
    key,
    label,
    faction_id,
    faction_key,
    rank_id,
    wallet,
    amount,
    cooldown_seconds,
    is_active
)
SELECT
    seeded_rules.key,
    seeded_rules.label,
    factions.id,
    seeded_rules.faction_key,
    NULL,
    seeded_rules.wallet,
    seeded_rules.amount,
    seeded_rules.cooldown_seconds,
    seeded_rules.is_active
FROM seeded_rules
INNER JOIN factions
    ON factions.type = seeded_rules.faction_key
ON CONFLICT (key) DO UPDATE
SET
    label = EXCLUDED.label,
    faction_id = EXCLUDED.faction_id,
    faction_key = EXCLUDED.faction_key,
    rank_id = EXCLUDED.rank_id,
    wallet = EXCLUDED.wallet,
    amount = EXCLUDED.amount,
    cooldown_seconds = EXCLUDED.cooldown_seconds,
    is_active = EXCLUDED.is_active,
    updated_at = NOW();

COMMIT;

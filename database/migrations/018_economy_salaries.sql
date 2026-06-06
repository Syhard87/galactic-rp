BEGIN;

CREATE TABLE IF NOT EXISTS economy_salary_rules (
    id BIGSERIAL PRIMARY KEY,
    key VARCHAR(64) NOT NULL UNIQUE,
    label VARCHAR(128) NOT NULL,
    faction_id BIGINT REFERENCES factions(id) ON DELETE SET NULL,
    faction_key VARCHAR(64),
    rank_id BIGINT REFERENCES faction_ranks(id) ON DELETE SET NULL,
    wallet VARCHAR(16) NOT NULL CHECK (wallet IN ('cash', 'bank')),
    amount BIGINT NOT NULL CHECK (amount > 0 AND amount <= 1000000),
    cooldown_seconds BIGINT NOT NULL CHECK (cooldown_seconds > 0),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_economy_salary_rules_faction_id
    ON economy_salary_rules(faction_id);

CREATE INDEX IF NOT EXISTS idx_economy_salary_rules_faction_key
    ON economy_salary_rules(faction_key);

CREATE INDEX IF NOT EXISTS idx_economy_salary_rules_rank_id
    ON economy_salary_rules(rank_id);

CREATE INDEX IF NOT EXISTS idx_economy_salary_rules_is_active
    ON economy_salary_rules(is_active);

CREATE TABLE IF NOT EXISTS character_salary_claims (
    character_id BIGINT NOT NULL REFERENCES characters(id) ON DELETE CASCADE,
    salary_rule_id BIGINT NOT NULL REFERENCES economy_salary_rules(id) ON DELETE CASCADE,
    last_claimed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    claim_count BIGINT NOT NULL DEFAULT 1 CHECK (claim_count >= 0),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (character_id, salary_rule_id)
);

CREATE INDEX IF NOT EXISTS idx_character_salary_claims_last_claimed_at
    ON character_salary_claims(last_claimed_at);

COMMIT;

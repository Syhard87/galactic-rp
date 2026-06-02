BEGIN;

CREATE TABLE IF NOT EXISTS reputation_definitions (
    key VARCHAR(64) PRIMARY KEY,
    name VARCHAR(128) NOT NULL,
    description TEXT,
    min_value INTEGER NOT NULL DEFAULT -1000,
    max_value INTEGER NOT NULL DEFAULT 1000,
    default_value INTEGER NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_reputation_definitions_value_bounds CHECK (min_value <= max_value),
    CONSTRAINT chk_reputation_definitions_default_in_bounds CHECK (default_value >= min_value AND default_value <= max_value)
);

CREATE TABLE IF NOT EXISTS character_reputations (
    id BIGSERIAL PRIMARY KEY,
    character_id BIGINT NOT NULL REFERENCES characters(id) ON DELETE CASCADE,
    reputation_key VARCHAR(64) NOT NULL REFERENCES reputation_definitions(key) ON DELETE CASCADE,
    value INTEGER NOT NULL DEFAULT 0,
    rank VARCHAR(32) NOT NULL DEFAULT 'neutral',
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_character_reputations_character_reputation UNIQUE (character_id, reputation_key)
);

CREATE INDEX IF NOT EXISTS idx_character_reputations_character_id
ON character_reputations(character_id);

CREATE INDEX IF NOT EXISTS idx_character_reputations_reputation_key
ON character_reputations(reputation_key);

COMMIT;

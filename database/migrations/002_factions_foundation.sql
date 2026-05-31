BEGIN;

CREATE TABLE IF NOT EXISTS factions (
    id BIGSERIAL PRIMARY KEY,
    name VARCHAR(128) NOT NULL UNIQUE,
    type VARCHAR(64) NOT NULL,
    description TEXT,
    is_whitelisted BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS faction_ranks (
    id BIGSERIAL PRIMARY KEY,
    faction_id BIGINT NOT NULL REFERENCES factions(id) ON DELETE CASCADE,
    name VARCHAR(128) NOT NULL,
    level INTEGER NOT NULL CHECK (level >= 1),
    permissions_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_faction_ranks_faction_level UNIQUE (faction_id, level),
    CONSTRAINT uq_faction_ranks_faction_name UNIQUE (faction_id, name)
);

ALTER TABLE characters
    ADD COLUMN IF NOT EXISTS faction_id BIGINT REFERENCES factions(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS rank_id BIGINT REFERENCES faction_ranks(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_characters_faction_id ON characters (faction_id);
CREATE INDEX IF NOT EXISTS idx_characters_rank_id ON characters (rank_id);
CREATE INDEX IF NOT EXISTS idx_faction_ranks_faction_id ON faction_ranks (faction_id);
CREATE INDEX IF NOT EXISTS idx_factions_type ON factions (type);

COMMIT;

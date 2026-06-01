BEGIN;

CREATE TABLE IF NOT EXISTS quests (
    key VARCHAR(64) PRIMARY KEY,
    title VARCHAR(128) NOT NULL,
    description TEXT,
    reward_xp INTEGER NOT NULL DEFAULT 0,
    is_repeatable BOOLEAN NOT NULL DEFAULT FALSE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_quests_reward_xp_positive CHECK (reward_xp >= 0)
);

CREATE TABLE IF NOT EXISTS character_quests (
    id BIGSERIAL PRIMARY KEY,
    character_id BIGINT NOT NULL REFERENCES characters(id) ON DELETE CASCADE,
    quest_key VARCHAR(64) NOT NULL REFERENCES quests(key) ON DELETE RESTRICT,
    status VARCHAR(32) NOT NULL DEFAULT 'started',
    started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_character_quests_status CHECK (status IN ('started', 'completed', 'abandoned'))
);

CREATE INDEX IF NOT EXISTS idx_character_quests_character_id
ON character_quests(character_id);

CREATE INDEX IF NOT EXISTS idx_character_quests_quest_key
ON character_quests(quest_key);

CREATE INDEX IF NOT EXISTS idx_character_quests_status
ON character_quests(status);

CREATE UNIQUE INDEX IF NOT EXISTS ux_character_quests_active_once
ON character_quests(character_id, quest_key)
WHERE status = 'started';

COMMIT;

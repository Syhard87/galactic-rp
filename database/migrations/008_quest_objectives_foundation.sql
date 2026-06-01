BEGIN;

CREATE TABLE IF NOT EXISTS quest_objectives (
    quest_key VARCHAR(64) NOT NULL REFERENCES quests(key) ON DELETE CASCADE,
    objective_key VARCHAR(64) NOT NULL,
    description TEXT NOT NULL,
    target_type VARCHAR(64) NOT NULL,
    target_key VARCHAR(64),
    required_count INTEGER NOT NULL DEFAULT 1,
    order_index INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    PRIMARY KEY (quest_key, objective_key),

    CONSTRAINT chk_quest_objectives_required_count_positive CHECK (required_count > 0)
);

CREATE TABLE IF NOT EXISTS character_quest_objectives (
    character_quest_id BIGINT NOT NULL REFERENCES character_quests(id) ON DELETE CASCADE,
    objective_key VARCHAR(64) NOT NULL,
    current_count INTEGER NOT NULL DEFAULT 0,
    required_count INTEGER NOT NULL DEFAULT 1,
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    PRIMARY KEY (character_quest_id, objective_key),

    CONSTRAINT chk_character_quest_objectives_current_count_positive CHECK (current_count >= 0),
    CONSTRAINT chk_character_quest_objectives_required_count_positive CHECK (required_count > 0)
);

CREATE INDEX IF NOT EXISTS idx_quest_objectives_quest_key
ON quest_objectives(quest_key);

CREATE INDEX IF NOT EXISTS idx_quest_objectives_target
ON quest_objectives(target_type, target_key);

CREATE INDEX IF NOT EXISTS idx_character_quest_objectives_character_quest_id
ON character_quest_objectives(character_quest_id);

COMMIT;

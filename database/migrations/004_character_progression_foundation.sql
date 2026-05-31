BEGIN;

CREATE TABLE IF NOT EXISTS character_progression (
    character_id BIGINT PRIMARY KEY REFERENCES characters(id) ON DELETE CASCADE,
    level INTEGER NOT NULL DEFAULT 1,
    current_xp INTEGER NOT NULL DEFAULT 0,
    total_xp INTEGER NOT NULL DEFAULT 0,
    class_key VARCHAR(64) NOT NULL DEFAULT 'civilian',
    specialization_key VARCHAR(64),
    unspent_talent_points INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_character_progression_level_positive CHECK (level >= 1),
    CONSTRAINT chk_character_progression_current_xp_positive CHECK (current_xp >= 0),
    CONSTRAINT chk_character_progression_total_xp_positive CHECK (total_xp >= 0),
    CONSTRAINT chk_character_progression_talent_points_positive CHECK (unspent_talent_points >= 0)
);

CREATE INDEX IF NOT EXISTS idx_character_progression_class_key
ON character_progression(class_key);

COMMIT;

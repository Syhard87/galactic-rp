BEGIN;

CREATE TABLE IF NOT EXISTS character_skills (
    character_id BIGINT NOT NULL REFERENCES characters(id) ON DELETE CASCADE,
    skill_key VARCHAR(64) NOT NULL,
    level INTEGER NOT NULL DEFAULT 1,
    current_xp INTEGER NOT NULL DEFAULT 0,
    total_xp INTEGER NOT NULL DEFAULT 0,
    last_gain_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    PRIMARY KEY (character_id, skill_key),

    CONSTRAINT chk_character_skills_level_positive CHECK (level >= 1),
    CONSTRAINT chk_character_skills_current_xp_positive CHECK (current_xp >= 0),
    CONSTRAINT chk_character_skills_total_xp_positive CHECK (total_xp >= 0)
);

ALTER TABLE character_skills
    ADD COLUMN IF NOT EXISTS current_xp INTEGER NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS total_xp INTEGER NOT NULL DEFAULT 0;

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_name = 'character_skills'
          AND column_name = 'xp'
    ) THEN
        EXECUTE $sql$
            UPDATE character_skills
            SET
                current_xp = CASE
                    WHEN current_xp = 0 THEN COALESCE(xp, 0)
                    ELSE current_xp
                END,
                total_xp = CASE
                    WHEN total_xp = 0 THEN COALESCE(xp, 0)
                    ELSE total_xp
                END,
                updated_at = NOW()
            WHERE
                current_xp = 0
                OR total_xp = 0
        $sql$;
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'chk_character_skills_current_xp_positive'
    ) THEN
        ALTER TABLE character_skills
        ADD CONSTRAINT chk_character_skills_current_xp_positive CHECK (current_xp >= 0);
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'chk_character_skills_total_xp_positive'
    ) THEN
        ALTER TABLE character_skills
        ADD CONSTRAINT chk_character_skills_total_xp_positive CHECK (total_xp >= 0);
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_character_skills_character_id
ON character_skills(character_id);

CREATE INDEX IF NOT EXISTS idx_character_skills_skill_key
ON character_skills(skill_key);

COMMIT;

BEGIN;

ALTER TABLE quests
ADD COLUMN IF NOT EXISTS reward_skill_key VARCHAR(64);

ALTER TABLE quests
ADD COLUMN IF NOT EXISTS reward_skill_xp INTEGER NOT NULL DEFAULT 0;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'chk_quests_reward_skill_xp_positive'
    ) THEN
        ALTER TABLE quests
        ADD CONSTRAINT chk_quests_reward_skill_xp_positive
        CHECK (reward_skill_xp >= 0);
    END IF;
END
$$;

COMMIT;

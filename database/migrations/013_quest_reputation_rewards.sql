BEGIN;

ALTER TABLE quests
ADD COLUMN IF NOT EXISTS reward_reputation_key VARCHAR(64);

ALTER TABLE quests
ADD COLUMN IF NOT EXISTS reward_reputation_amount INTEGER NOT NULL DEFAULT 0;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'chk_quests_reward_reputation_amount_range'
    ) THEN
        ALTER TABLE quests
        ADD CONSTRAINT chk_quests_reward_reputation_amount_range
        CHECK (reward_reputation_amount BETWEEN -1000 AND 1000);
    END IF;
END
$$;

COMMIT;

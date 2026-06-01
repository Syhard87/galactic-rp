BEGIN;

ALTER TABLE quests
ADD COLUMN IF NOT EXISTS reward_item_key VARCHAR(64);

ALTER TABLE quests
ADD COLUMN IF NOT EXISTS reward_item_quantity INTEGER NOT NULL DEFAULT 0;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'chk_quests_reward_item_quantity_positive'
    ) THEN
        ALTER TABLE quests
        ADD CONSTRAINT chk_quests_reward_item_quantity_positive
        CHECK (reward_item_quantity >= 0);
    END IF;
END
$$;

COMMIT;

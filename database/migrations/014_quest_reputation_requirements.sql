BEGIN;

ALTER TABLE quests
ADD COLUMN IF NOT EXISTS required_reputation_key VARCHAR(64);

ALTER TABLE quests
ADD COLUMN IF NOT EXISTS required_reputation_min_value INTEGER NOT NULL DEFAULT 0;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'chk_quests_required_reputation_min_value_range'
    ) THEN
        ALTER TABLE quests
        ADD CONSTRAINT chk_quests_required_reputation_min_value_range
        CHECK (required_reputation_min_value BETWEEN -1000 AND 1000);
    END IF;
END
$$;

COMMIT;

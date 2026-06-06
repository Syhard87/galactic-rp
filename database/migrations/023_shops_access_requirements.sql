BEGIN;

ALTER TABLE shops
ADD COLUMN IF NOT EXISTS required_reputation_key VARCHAR(100);

ALTER TABLE shops
ADD COLUMN IF NOT EXISTS required_reputation_min_value INTEGER;

ALTER TABLE shops
ADD COLUMN IF NOT EXISTS required_faction_key VARCHAR(100);

ALTER TABLE shop_items
ADD COLUMN IF NOT EXISTS required_reputation_key VARCHAR(100);

ALTER TABLE shop_items
ADD COLUMN IF NOT EXISTS required_reputation_min_value INTEGER;

ALTER TABLE shop_items
ADD COLUMN IF NOT EXISTS required_faction_key VARCHAR(100);

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'chk_shops_required_reputation_min_value_non_negative'
    ) THEN
        ALTER TABLE shops
        ADD CONSTRAINT chk_shops_required_reputation_min_value_non_negative
        CHECK (
            required_reputation_min_value IS NULL
            OR required_reputation_min_value >= 0
        );
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'chk_shop_items_required_reputation_min_value_non_negative'
    ) THEN
        ALTER TABLE shop_items
        ADD CONSTRAINT chk_shop_items_required_reputation_min_value_non_negative
        CHECK (
            required_reputation_min_value IS NULL
            OR required_reputation_min_value >= 0
        );
    END IF;
END $$;

COMMIT;

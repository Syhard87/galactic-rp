BEGIN;

ALTER TABLE shop_items
ADD COLUMN IF NOT EXISTS sell_price INTEGER;

ALTER TABLE shop_items
ADD COLUMN IF NOT EXISTS is_sellable BOOLEAN NOT NULL DEFAULT FALSE;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'chk_shop_items_sell_price_positive'
    ) THEN
        ALTER TABLE shop_items
        ADD CONSTRAINT chk_shop_items_sell_price_positive
        CHECK (sell_price IS NULL OR sell_price > 0);
    END IF;
END $$;

COMMIT;

BEGIN;

ALTER TABLE shop_items
ADD COLUMN IF NOT EXISTS stock_enabled BOOLEAN NOT NULL DEFAULT FALSE;

ALTER TABLE shop_items
ADD COLUMN IF NOT EXISTS stock_quantity INTEGER;

ALTER TABLE shop_items
ADD COLUMN IF NOT EXISTS max_stock INTEGER;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'chk_shop_items_stock_quantity_non_negative'
    ) THEN
        ALTER TABLE shop_items
        ADD CONSTRAINT chk_shop_items_stock_quantity_non_negative
        CHECK (stock_quantity IS NULL OR stock_quantity >= 0);
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'chk_shop_items_max_stock_non_negative'
    ) THEN
        ALTER TABLE shop_items
        ADD CONSTRAINT chk_shop_items_max_stock_non_negative
        CHECK (max_stock IS NULL OR max_stock >= 0);
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'chk_shop_items_stock_quantity_within_max_stock'
    ) THEN
        ALTER TABLE shop_items
        ADD CONSTRAINT chk_shop_items_stock_quantity_within_max_stock
        CHECK (
            stock_quantity IS NULL
            OR max_stock IS NULL
            OR stock_quantity <= max_stock
        );
    END IF;
END $$;

COMMIT;

BEGIN;

ALTER TABLE contracts
ADD COLUMN IF NOT EXISTS required_item_key VARCHAR(100);

ALTER TABLE contracts
ADD COLUMN IF NOT EXISTS required_item_quantity INTEGER NOT NULL DEFAULT 0;

ALTER TABLE contracts
ADD COLUMN IF NOT EXISTS consume_required_items BOOLEAN NOT NULL DEFAULT true;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'chk_contracts_required_item_quantity_non_negative'
    ) THEN
        ALTER TABLE contracts
        ADD CONSTRAINT chk_contracts_required_item_quantity_non_negative
        CHECK (required_item_quantity >= 0);
    END IF;
END
$$;

COMMIT;

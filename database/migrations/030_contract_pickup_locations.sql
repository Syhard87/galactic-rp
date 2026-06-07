BEGIN;

ALTER TABLE contracts
ADD COLUMN IF NOT EXISTS pickup_location_key VARCHAR(100);

ALTER TABLE contracts
ADD COLUMN IF NOT EXISTS requires_pickup_location BOOLEAN NOT NULL DEFAULT false;

ALTER TABLE contracts
ADD COLUMN IF NOT EXISTS pickup_status VARCHAR(50) NOT NULL DEFAULT 'none';

ALTER TABLE contracts
ADD COLUMN IF NOT EXISTS picked_up_at TIMESTAMPTZ;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'chk_contracts_pickup_status_valid'
    ) THEN
        ALTER TABLE contracts
        ADD CONSTRAINT chk_contracts_pickup_status_valid
        CHECK (pickup_status IN ('none', 'pending', 'picked_up'));
    END IF;
END
$$;

COMMIT;

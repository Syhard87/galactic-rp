BEGIN;

ALTER TABLE shops
ADD COLUMN IF NOT EXISTS position_x DOUBLE PRECISION;

ALTER TABLE shops
ADD COLUMN IF NOT EXISTS position_y DOUBLE PRECISION;

ALTER TABLE shops
ADD COLUMN IF NOT EXISTS position_z DOUBLE PRECISION;

ALTER TABLE shops
ADD COLUMN IF NOT EXISTS radius DOUBLE PRECISION NOT NULL DEFAULT 250.0;

ALTER TABLE shops
ADD COLUMN IF NOT EXISTS requires_proximity BOOLEAN NOT NULL DEFAULT FALSE;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'chk_shops_radius_positive'
    ) THEN
        ALTER TABLE shops
        ADD CONSTRAINT chk_shops_radius_positive
        CHECK (radius > 0);
    END IF;
END $$;

COMMIT;

BEGIN;

CREATE TABLE IF NOT EXISTS contract_delivery_locations (
    id BIGSERIAL PRIMARY KEY,
    key VARCHAR(100) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description TEXT,
    location_type VARCHAR(100) NOT NULL DEFAULT 'delivery',
    position_x DOUBLE PRECISION,
    position_y DOUBLE PRECISION,
    position_z DOUBLE PRECISION,
    radius DOUBLE PRECISION NOT NULL DEFAULT 500.0,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'chk_contract_delivery_locations_radius_positive'
    ) THEN
        ALTER TABLE contract_delivery_locations
        ADD CONSTRAINT chk_contract_delivery_locations_radius_positive
        CHECK (radius > 0);
    END IF;
END
$$;

CREATE INDEX IF NOT EXISTS idx_contract_delivery_locations_key
ON contract_delivery_locations(key);

CREATE INDEX IF NOT EXISTS idx_contract_delivery_locations_is_active
ON contract_delivery_locations(is_active);

ALTER TABLE contracts
ADD COLUMN IF NOT EXISTS delivery_location_key VARCHAR(100);

ALTER TABLE contracts
ADD COLUMN IF NOT EXISTS requires_delivery_location BOOLEAN NOT NULL DEFAULT false;

COMMIT;

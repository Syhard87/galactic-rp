BEGIN;

CREATE TABLE IF NOT EXISTS crafting_stations (
    key VARCHAR(64) PRIMARY KEY,
    name VARCHAR(128) NOT NULL,
    station_type VARCHAR(64) NOT NULL,
    position_x DOUBLE PRECISION NOT NULL,
    position_y DOUBLE PRECISION NOT NULL,
    position_z DOUBLE PRECISION NOT NULL,
    radius DOUBLE PRECISION NOT NULL DEFAULT 250,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_crafting_stations_radius_positive CHECK (radius > 0)
);

CREATE INDEX IF NOT EXISTS idx_crafting_stations_station_type
ON crafting_stations(station_type);

ALTER TABLE crafting_recipes
ADD COLUMN IF NOT EXISTS station_key VARCHAR(64);

COMMIT;

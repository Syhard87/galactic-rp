BEGIN;

CREATE TABLE IF NOT EXISTS items (
    key VARCHAR(64) PRIMARY KEY,
    name VARCHAR(128) NOT NULL,
    description TEXT,
    weight NUMERIC(10,2) NOT NULL DEFAULT 0,
    is_stackable BOOLEAN NOT NULL DEFAULT TRUE,
    is_illegal BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS inventory_items (
    id BIGSERIAL PRIMARY KEY,
    character_id BIGINT NOT NULL REFERENCES characters(id) ON DELETE CASCADE,
    item_key VARCHAR(64) NOT NULL REFERENCES items(key) ON DELETE RESTRICT,
    quantity INTEGER NOT NULL DEFAULT 1 CHECK (quantity > 0),
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_inventory_items_character_id ON inventory_items (character_id);
CREATE INDEX IF NOT EXISTS idx_inventory_items_item_key ON inventory_items (item_key);

COMMIT;

BEGIN;

CREATE TABLE IF NOT EXISTS shops (
    id BIGSERIAL PRIMARY KEY,
    key VARCHAR(64) NOT NULL UNIQUE,
    name VARCHAR(128) NOT NULL,
    description TEXT,
    shop_type VARCHAR(64),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS shop_items (
    id BIGSERIAL PRIMARY KEY,
    shop_id BIGINT NOT NULL REFERENCES shops(id) ON DELETE CASCADE,
    item_key VARCHAR(64) NOT NULL REFERENCES items(key) ON DELETE RESTRICT,
    wallet VARCHAR(16) NOT NULL CHECK (wallet IN ('cash', 'bank')),
    price BIGINT NOT NULL CHECK (price > 0),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_shop_items_shop_item UNIQUE (shop_id, item_key)
);

CREATE INDEX IF NOT EXISTS idx_shops_key ON shops(key);
CREATE INDEX IF NOT EXISTS idx_shop_items_item_key ON shop_items(item_key);
CREATE INDEX IF NOT EXISTS idx_shop_items_shop_id ON shop_items(shop_id);

COMMIT;

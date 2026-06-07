BEGIN;

CREATE TABLE IF NOT EXISTS contract_route_templates (
    id BIGSERIAL PRIMARY KEY,
    key VARCHAR(100) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    description TEXT,
    item_key VARCHAR(100) NOT NULL,
    item_quantity INTEGER NOT NULL,
    reward_money INTEGER NOT NULL DEFAULT 0,
    pickup_location_key VARCHAR(100) NOT NULL,
    delivery_location_key VARCHAR(100) NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'chk_contract_route_templates_item_quantity_positive'
    ) THEN
        ALTER TABLE contract_route_templates
        ADD CONSTRAINT chk_contract_route_templates_item_quantity_positive
        CHECK (item_quantity > 0);
    END IF;
END
$$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'chk_contract_route_templates_reward_money_non_negative'
    ) THEN
        ALTER TABLE contract_route_templates
        ADD CONSTRAINT chk_contract_route_templates_reward_money_non_negative
        CHECK (reward_money >= 0);
    END IF;
END
$$;

CREATE INDEX IF NOT EXISTS idx_contract_route_templates_key
ON contract_route_templates(key);

CREATE INDEX IF NOT EXISTS idx_contract_route_templates_pickup_location_key
ON contract_route_templates(pickup_location_key);

CREATE INDEX IF NOT EXISTS idx_contract_route_templates_delivery_location_key
ON contract_route_templates(delivery_location_key);

CREATE INDEX IF NOT EXISTS idx_contract_route_templates_is_active
ON contract_route_templates(is_active);

COMMIT;

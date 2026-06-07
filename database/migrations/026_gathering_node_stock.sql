ALTER TABLE gathering_nodes
ADD COLUMN IF NOT EXISTS stock_enabled BOOLEAN NOT NULL DEFAULT FALSE;

ALTER TABLE gathering_nodes
ADD COLUMN IF NOT EXISTS stock_quantity INTEGER;

ALTER TABLE gathering_nodes
ADD COLUMN IF NOT EXISTS max_stock INTEGER;

ALTER TABLE gathering_nodes
ADD COLUMN IF NOT EXISTS restock_seconds INTEGER;

ALTER TABLE gathering_nodes
ADD COLUMN IF NOT EXISTS last_restock_at TIMESTAMPTZ;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'gathering_nodes_stock_quantity_check'
    ) THEN
        ALTER TABLE gathering_nodes
        ADD CONSTRAINT gathering_nodes_stock_quantity_check
        CHECK (stock_quantity IS NULL OR stock_quantity >= 0);
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'gathering_nodes_max_stock_check'
    ) THEN
        ALTER TABLE gathering_nodes
        ADD CONSTRAINT gathering_nodes_max_stock_check
        CHECK (max_stock IS NULL OR max_stock >= 0);
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'gathering_nodes_stock_max_relation_check'
    ) THEN
        ALTER TABLE gathering_nodes
        ADD CONSTRAINT gathering_nodes_stock_max_relation_check
        CHECK (
            stock_quantity IS NULL
            OR max_stock IS NULL
            OR stock_quantity <= max_stock
        );
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'gathering_nodes_restock_seconds_check'
    ) THEN
        ALTER TABLE gathering_nodes
        ADD CONSTRAINT gathering_nodes_restock_seconds_check
        CHECK (restock_seconds IS NULL OR restock_seconds > 0);
    END IF;
END $$;

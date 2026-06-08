BEGIN;

ALTER TABLE contracts
ADD COLUMN IF NOT EXISTS deadline_seconds INTEGER;

ALTER TABLE contracts
ADD COLUMN IF NOT EXISTS expires_at TIMESTAMPTZ;

ALTER TABLE contracts
ADD COLUMN IF NOT EXISTS expired_at TIMESTAMPTZ;

ALTER TABLE contract_route_templates
ADD COLUMN IF NOT EXISTS deadline_seconds INTEGER;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'chk_contracts_deadline_seconds_positive'
    ) THEN
        ALTER TABLE contracts
        ADD CONSTRAINT chk_contracts_deadline_seconds_positive
        CHECK (deadline_seconds IS NULL OR deadline_seconds > 0);
    END IF;
END
$$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'chk_contract_route_templates_deadline_seconds_positive'
    ) THEN
        ALTER TABLE contract_route_templates
        ADD CONSTRAINT chk_contract_route_templates_deadline_seconds_positive
        CHECK (deadline_seconds IS NULL OR deadline_seconds > 0);
    END IF;
END
$$;

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'chk_contracts_status_allowed'
    ) THEN
        ALTER TABLE contracts
        DROP CONSTRAINT chk_contracts_status_allowed;
    END IF;

    ALTER TABLE contracts
    ADD CONSTRAINT chk_contracts_status_allowed
    CHECK (status IN ('open', 'accepted', 'completed', 'cancelled', 'expired'));
END
$$;

CREATE INDEX IF NOT EXISTS idx_contracts_expires_at
ON contracts(expires_at);

COMMIT;

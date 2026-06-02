BEGIN;

ALTER TABLE contracts
ADD COLUMN IF NOT EXISTS payment_status VARCHAR(32) NOT NULL DEFAULT 'pending';

ALTER TABLE contracts
ADD COLUMN IF NOT EXISTS paid_at TIMESTAMPTZ;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'chk_contracts_payment_status_allowed'
    ) THEN
        ALTER TABLE contracts
        ADD CONSTRAINT chk_contracts_payment_status_allowed
        CHECK (payment_status IN ('pending', 'paid', 'unavailable', 'failed'));
    END IF;
END
$$;

CREATE INDEX IF NOT EXISTS idx_contracts_payment_status
ON contracts(payment_status);

COMMIT;

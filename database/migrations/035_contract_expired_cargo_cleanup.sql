BEGIN;

ALTER TABLE contracts
ADD COLUMN IF NOT EXISTS cargo_cleanup_status VARCHAR(50) NOT NULL DEFAULT 'none';

ALTER TABLE contracts
ADD COLUMN IF NOT EXISTS cargo_cleaned_at TIMESTAMPTZ;

ALTER TABLE contracts
ADD COLUMN IF NOT EXISTS cargo_cleanup_error VARCHAR(255);

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'chk_contracts_cargo_cleanup_status_valid'
    ) THEN
        ALTER TABLE contracts
        ADD CONSTRAINT chk_contracts_cargo_cleanup_status_valid
        CHECK (cargo_cleanup_status IN ('none', 'not_required', 'pending', 'cleaned', 'failed'));
    END IF;
END
$$;

CREATE INDEX IF NOT EXISTS idx_contracts_cargo_cleanup_status
ON contracts(cargo_cleanup_status);

COMMIT;

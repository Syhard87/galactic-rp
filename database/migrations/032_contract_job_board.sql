BEGIN;

ALTER TABLE contracts
ADD COLUMN IF NOT EXISTS source_route_key VARCHAR(100);

ALTER TABLE contracts
ADD COLUMN IF NOT EXISTS job_source VARCHAR(50);

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'chk_contracts_job_source_allowed'
    ) THEN
        ALTER TABLE contracts
        ADD CONSTRAINT chk_contracts_job_source_allowed
        CHECK (
            job_source IS NULL
            OR job_source IN ('manual', 'route_template', 'job_board')
        );
    END IF;
END
$$;

COMMIT;

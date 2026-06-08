BEGIN;

ALTER TABLE contract_route_templates
ADD COLUMN IF NOT EXISTS required_skill_key VARCHAR(100);

ALTER TABLE contract_route_templates
ADD COLUMN IF NOT EXISTS required_skill_level INTEGER NOT NULL DEFAULT 0;

ALTER TABLE contract_route_templates
ADD COLUMN IF NOT EXISTS required_reputation_key VARCHAR(100);

ALTER TABLE contract_route_templates
ADD COLUMN IF NOT EXISTS required_reputation_min INTEGER NOT NULL DEFAULT 0;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'contract_route_templates_required_skill_level_check'
    ) THEN
        ALTER TABLE contract_route_templates
        ADD CONSTRAINT contract_route_templates_required_skill_level_check
        CHECK (required_skill_level >= 0);
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_contract_route_templates_required_skill
ON contract_route_templates(required_skill_key);

CREATE INDEX IF NOT EXISTS idx_contract_route_templates_required_reputation
ON contract_route_templates(required_reputation_key);

COMMIT;

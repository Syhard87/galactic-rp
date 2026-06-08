BEGIN;

ALTER TABLE contracts
ADD COLUMN IF NOT EXISTS reward_skill_key VARCHAR(100);

ALTER TABLE contracts
ADD COLUMN IF NOT EXISTS reward_skill_xp INTEGER NOT NULL DEFAULT 0;

ALTER TABLE contracts
ADD COLUMN IF NOT EXISTS reward_reputation_key VARCHAR(100);

ALTER TABLE contracts
ADD COLUMN IF NOT EXISTS reward_reputation_delta INTEGER NOT NULL DEFAULT 0;

ALTER TABLE contracts
ADD COLUMN IF NOT EXISTS rewards_status VARCHAR(50) NOT NULL DEFAULT 'none';

ALTER TABLE contracts
ADD COLUMN IF NOT EXISTS rewards_granted_at TIMESTAMPTZ;

ALTER TABLE contracts
ADD COLUMN IF NOT EXISTS rewards_error VARCHAR(255);

ALTER TABLE contract_route_templates
ADD COLUMN IF NOT EXISTS reward_skill_key VARCHAR(100);

ALTER TABLE contract_route_templates
ADD COLUMN IF NOT EXISTS reward_skill_xp INTEGER NOT NULL DEFAULT 0;

ALTER TABLE contract_route_templates
ADD COLUMN IF NOT EXISTS reward_reputation_key VARCHAR(100);

ALTER TABLE contract_route_templates
ADD COLUMN IF NOT EXISTS reward_reputation_delta INTEGER NOT NULL DEFAULT 0;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'chk_contracts_reward_skill_xp_non_negative'
    ) THEN
        ALTER TABLE contracts
        ADD CONSTRAINT chk_contracts_reward_skill_xp_non_negative
        CHECK (reward_skill_xp >= 0);
    END IF;
END
$$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'chk_contracts_rewards_status_valid'
    ) THEN
        ALTER TABLE contracts
        ADD CONSTRAINT chk_contracts_rewards_status_valid
        CHECK (rewards_status IN ('none', 'pending', 'granted', 'failed', 'not_required'));
    END IF;
END
$$;

CREATE INDEX IF NOT EXISTS idx_contracts_rewards_status
ON contracts(rewards_status);

COMMIT;

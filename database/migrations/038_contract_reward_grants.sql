BEGIN;

CREATE TABLE IF NOT EXISTS contract_reward_grants (
    id SERIAL PRIMARY KEY,
    contract_id INTEGER NOT NULL,
    character_id INTEGER NOT NULL,
    reward_type VARCHAR(32) NOT NULL,
    reward_key VARCHAR(128),
    amount INTEGER NOT NULL,
    status VARCHAR(32) NOT NULL DEFAULT 'pending',
    error_message TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    applied_at TIMESTAMPTZ,
    CONSTRAINT fk_contract_reward_grants_contract
        FOREIGN KEY (contract_id) REFERENCES contracts(id) ON DELETE CASCADE
);

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'chk_contract_reward_grants_reward_type_valid'
    ) THEN
        ALTER TABLE contract_reward_grants
        ADD CONSTRAINT chk_contract_reward_grants_reward_type_valid
        CHECK (reward_type IN ('money', 'skill_xp', 'reputation'));
    END IF;
END
$$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'chk_contract_reward_grants_status_valid'
    ) THEN
        ALTER TABLE contract_reward_grants
        ADD CONSTRAINT chk_contract_reward_grants_status_valid
        CHECK (status IN ('pending', 'applied', 'failed'));
    END IF;
END
$$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'chk_contract_reward_grants_amount_positive'
    ) THEN
        ALTER TABLE contract_reward_grants
        ADD CONSTRAINT chk_contract_reward_grants_amount_positive
        CHECK (amount > 0);
    END IF;
END
$$;

CREATE UNIQUE INDEX IF NOT EXISTS uq_contract_reward_grant
ON contract_reward_grants(contract_id, reward_type, reward_key);

CREATE INDEX IF NOT EXISTS idx_contract_reward_grants_contract_id
ON contract_reward_grants(contract_id);

CREATE INDEX IF NOT EXISTS idx_contract_reward_grants_character_id
ON contract_reward_grants(character_id);

COMMIT;

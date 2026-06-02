BEGIN;

CREATE TABLE IF NOT EXISTS contracts (
    id BIGSERIAL PRIMARY KEY,
    creator_character_id BIGINT NOT NULL REFERENCES characters(id) ON DELETE CASCADE,
    assignee_character_id BIGINT REFERENCES characters(id) ON DELETE SET NULL,
    type VARCHAR(64) NOT NULL,
    title VARCHAR(128) NOT NULL,
    description TEXT NOT NULL,
    reward_money INTEGER NOT NULL DEFAULT 0,
    status VARCHAR(32) NOT NULL DEFAULT 'open',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    accepted_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    cancelled_at TIMESTAMPTZ,
    deadline_at TIMESTAMPTZ,

    CONSTRAINT chk_contracts_reward_money_non_negative CHECK (reward_money >= 0),
    CONSTRAINT chk_contracts_status_allowed CHECK (status IN ('open', 'accepted', 'completed', 'cancelled'))
);

CREATE INDEX IF NOT EXISTS idx_contracts_status
ON contracts(status);

CREATE INDEX IF NOT EXISTS idx_contracts_creator_character_id
ON contracts(creator_character_id);

CREATE INDEX IF NOT EXISTS idx_contracts_assignee_character_id
ON contracts(assignee_character_id);

COMMIT;

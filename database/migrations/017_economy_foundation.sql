BEGIN;

ALTER TABLE characters
ADD COLUMN IF NOT EXISTS money_cash BIGINT NOT NULL DEFAULT 0;

ALTER TABLE characters
ADD COLUMN IF NOT EXISTS money_bank BIGINT NOT NULL DEFAULT 0;

CREATE TABLE IF NOT EXISTS bank_transactions (
    id BIGSERIAL PRIMARY KEY,
    character_id BIGINT NOT NULL REFERENCES characters(id) ON DELETE CASCADE,
    target_character_id BIGINT REFERENCES characters(id) ON DELETE SET NULL,
    amount BIGINT NOT NULL CHECK (amount >= 0),
    currency VARCHAR(32) NOT NULL DEFAULT 'credits',
    wallet VARCHAR(16) NOT NULL CHECK (wallet IN ('cash', 'bank')),
    type VARCHAR(32) NOT NULL CHECK (type IN ('credit', 'debit', 'transfer_in', 'transfer_out', 'adjustment')),
    reason TEXT,
    metadata_json JSONB NOT NULL DEFAULT '{}'::JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_bank_transactions_character_id ON bank_transactions(character_id);
CREATE INDEX IF NOT EXISTS idx_bank_transactions_target_character_id ON bank_transactions(target_character_id);
CREATE INDEX IF NOT EXISTS idx_bank_transactions_created_at ON bank_transactions(created_at);

COMMIT;

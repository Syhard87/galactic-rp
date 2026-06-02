INSERT INTO reputation_definitions (
    key,
    name,
    description,
    min_value,
    max_value,
    default_value,
    is_active
)
VALUES
    ('government', 'Gouvernement local', 'Reputation aupres du gouvernement local.', -1000, 1000, 0, TRUE),
    ('military', 'Corps militaire', 'Reputation aupres du corps militaire.', -1000, 1000, 0, TRUE),
    ('merchant_guild', 'Guilde marchande', 'Reputation aupres de la guilde marchande.', -1000, 1000, 0, TRUE),
    ('underworld', 'Bas-fonds', 'Reputation aupres des reseaux criminels et des bas-fonds.', -1000, 1000, 0, TRUE),
    ('explorers', 'Explorateurs', 'Reputation aupres des explorateurs et eclaireurs.', -1000, 1000, 0, TRUE)
ON CONFLICT (key) DO UPDATE
SET
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    min_value = EXCLUDED.min_value,
    max_value = EXCLUDED.max_value,
    default_value = EXCLUDED.default_value,
    is_active = EXCLUDED.is_active,
    updated_at = NOW();

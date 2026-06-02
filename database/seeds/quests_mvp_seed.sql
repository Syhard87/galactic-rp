INSERT INTO quests (
    key,
    title,
    description,
    reward_xp,
    reward_item_key,
    reward_item_quantity,
    reward_skill_key,
    reward_skill_xp,
    reward_reputation_key,
    reward_reputation_amount,
    required_reputation_key,
    required_reputation_min_value,
    is_repeatable,
    is_active
)
VALUES
    ('first_steps', 'Premiers pas', 'Decouvrir les commandes de base du personnage', 50, 'credit_chip', 1, NULL, 0, NULL, 0, NULL, 0, FALSE, TRUE),
    ('medic_training', 'Formation medicale', 'Utiliser un medikit et progresser en medecine', 75, 'medkit_basic', 1, 'medicine', 50, 'government', 10, NULL, 0, FALSE, TRUE),
    ('explorer_report', 'Rapport d''exploration', 'Faire un premier rapport RP d''exploration', 75, 'ration_pack', 1, 'exploration', 50, 'explorers', 15, NULL, 0, FALSE, TRUE),
    ('government_contract', 'Contrat gouvernemental', 'Mission reservee aux personnages de confiance du gouvernement', 0, NULL, 0, NULL, 0, NULL, 0, 'government', 50, FALSE, TRUE),
    ('underworld_delivery', 'Livraison des bas-fonds', 'Mission reservee aux contacts fiables du sous-monde', 0, NULL, 0, NULL, 0, NULL, 0, 'underworld', 25, FALSE, TRUE),
    ('explorer_sensitive_task', 'Tache sensible d''exploration', 'Mission reservee aux explorateurs reputes', 0, NULL, 0, NULL, 0, NULL, 0, 'explorers', 30, FALSE, TRUE)
ON CONFLICT (key) DO UPDATE
SET
    title = EXCLUDED.title,
    description = EXCLUDED.description,
    reward_xp = EXCLUDED.reward_xp,
    reward_item_key = EXCLUDED.reward_item_key,
    reward_item_quantity = EXCLUDED.reward_item_quantity,
    reward_skill_key = EXCLUDED.reward_skill_key,
    reward_skill_xp = EXCLUDED.reward_skill_xp,
    reward_reputation_key = EXCLUDED.reward_reputation_key,
    reward_reputation_amount = EXCLUDED.reward_reputation_amount,
    required_reputation_key = EXCLUDED.required_reputation_key,
    required_reputation_min_value = EXCLUDED.required_reputation_min_value,
    is_repeatable = EXCLUDED.is_repeatable,
    is_active = EXCLUDED.is_active,
    updated_at = NOW();

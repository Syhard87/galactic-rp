INSERT INTO quests (
    key,
    title,
    description,
    reward_xp,
    reward_item_key,
    reward_item_quantity,
    reward_skill_key,
    reward_skill_xp,
    is_repeatable,
    is_active
)
VALUES
    ('first_steps', 'Premiers pas', 'Decouvrir les commandes de base du personnage', 50, 'credit_chip', 1, NULL, 0, FALSE, TRUE),
    ('medic_training', 'Formation medicale', 'Utiliser un medikit et progresser en medecine', 75, 'medkit_basic', 1, 'medicine', 50, FALSE, TRUE),
    ('explorer_report', 'Rapport d''exploration', 'Faire un premier rapport RP d''exploration', 75, 'ration_pack', 1, 'exploration', 50, FALSE, TRUE)
ON CONFLICT (key) DO UPDATE
SET
    title = EXCLUDED.title,
    description = EXCLUDED.description,
    reward_xp = EXCLUDED.reward_xp,
    reward_item_key = EXCLUDED.reward_item_key,
    reward_item_quantity = EXCLUDED.reward_item_quantity,
    reward_skill_key = EXCLUDED.reward_skill_key,
    reward_skill_xp = EXCLUDED.reward_skill_xp,
    is_repeatable = EXCLUDED.is_repeatable,
    is_active = EXCLUDED.is_active,
    updated_at = NOW();

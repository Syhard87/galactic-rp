INSERT INTO quests (key, title, description, reward_xp, is_repeatable, is_active)
VALUES
    ('first_steps', 'Premiers pas', 'Decouvrir les commandes de base du personnage', 50, FALSE, TRUE),
    ('medic_training', 'Formation medicale', 'Utiliser un medikit et progresser en medecine', 75, FALSE, TRUE),
    ('explorer_report', 'Rapport d''exploration', 'Faire un premier rapport RP d''exploration', 75, FALSE, TRUE)
ON CONFLICT (key) DO UPDATE
SET
    title = EXCLUDED.title,
    description = EXCLUDED.description,
    reward_xp = EXCLUDED.reward_xp,
    is_repeatable = EXCLUDED.is_repeatable,
    is_active = EXCLUDED.is_active,
    updated_at = NOW();

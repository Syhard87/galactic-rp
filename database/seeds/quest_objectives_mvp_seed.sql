INSERT INTO quest_objectives (
    quest_key,
    objective_key,
    description,
    target_type,
    target_key,
    required_count,
    order_index
)
VALUES
    ('first_steps', 'open_profile', 'Consulter son profil personnage', 'command', 'profile', 1, 1),
    ('medic_training', 'use_medkit', 'Utiliser un medikit basique', 'item_use', 'medkit_basic', 1, 1),
    ('explorer_report', 'write_report', 'Faire un rapport RP d''exploration', 'rp_action', 'exploration_report', 1, 1)
ON CONFLICT (quest_key, objective_key) DO UPDATE
SET
    description = EXCLUDED.description,
    target_type = EXCLUDED.target_type,
    target_key = EXCLUDED.target_key,
    required_count = EXCLUDED.required_count,
    order_index = EXCLUDED.order_index,
    updated_at = NOW();

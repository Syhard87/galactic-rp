INSERT INTO items (key, name, description, weight, is_stackable, is_illegal)
VALUES
    ('credit_chip', 'Puce de credits', 'Objet monetaire RP', 0.01, TRUE, FALSE),
    ('comlink', 'Comlink', 'Communication basique', 0.20, FALSE, FALSE),
    ('medkit_basic', 'Medikit basique', 'Permet de soigner des blessures legeres', 1.50, TRUE, FALSE),
    ('ration_pack', 'Ration alimentaire', 'Nourriture de survie', 0.75, TRUE, FALSE),
    ('id_card', 'Carte d''identite', 'Document d''identification RP', 0.05, FALSE, FALSE)
ON CONFLICT (key) DO UPDATE
SET
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    weight = EXCLUDED.weight,
    is_stackable = EXCLUDED.is_stackable,
    is_illegal = EXCLUDED.is_illegal,
    updated_at = NOW();

INSERT INTO crafting_recipes (
    key,
    category,
    result_item_key,
    result_quantity,
    required_skill_key,
    required_skill_level,
    craft_xp_skill_key,
    craft_xp_amount,
    duration_seconds,
    is_active
)
VALUES
    ('medkit_basic', 'medical', 'medkit_basic', 1, NULL, 0, 'medicine', 20, 0, TRUE),
    ('ration_pack', 'survival', 'ration_pack', 1, NULL, 0, 'survival', 10, 0, TRUE),
    ('comlink', 'utility', 'comlink', 1, NULL, 0, 'crafting', 15, 0, TRUE)
ON CONFLICT (key) DO UPDATE
SET
    category = EXCLUDED.category,
    result_item_key = EXCLUDED.result_item_key,
    result_quantity = EXCLUDED.result_quantity,
    required_skill_key = EXCLUDED.required_skill_key,
    required_skill_level = EXCLUDED.required_skill_level,
    craft_xp_skill_key = EXCLUDED.craft_xp_skill_key,
    craft_xp_amount = EXCLUDED.craft_xp_amount,
    duration_seconds = EXCLUDED.duration_seconds,
    is_active = EXCLUDED.is_active,
    updated_at = NOW();

INSERT INTO crafting_recipe_ingredients (
    recipe_key,
    item_key,
    quantity
)
VALUES
    ('medkit_basic', 'credit_chip', 2),
    ('ration_pack', 'credit_chip', 1),
    ('comlink', 'credit_chip', 3)
ON CONFLICT (recipe_key, item_key) DO UPDATE
SET
    quantity = EXCLUDED.quantity;

BEGIN;

CREATE TABLE IF NOT EXISTS crafting_recipes (
    key VARCHAR(64) PRIMARY KEY,
    category VARCHAR(64) NOT NULL,
    result_item_key VARCHAR(64) NOT NULL REFERENCES items(key) ON DELETE RESTRICT,
    result_quantity INTEGER NOT NULL DEFAULT 1,
    required_skill_key VARCHAR(64),
    required_skill_level INTEGER NOT NULL DEFAULT 0,
    craft_xp_skill_key VARCHAR(64),
    craft_xp_amount INTEGER NOT NULL DEFAULT 0,
    duration_seconds INTEGER NOT NULL DEFAULT 0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_crafting_recipes_result_quantity_positive CHECK (result_quantity > 0),
    CONSTRAINT chk_crafting_recipes_required_skill_level_positive CHECK (required_skill_level >= 0),
    CONSTRAINT chk_crafting_recipes_craft_xp_amount_positive CHECK (craft_xp_amount >= 0),
    CONSTRAINT chk_crafting_recipes_duration_seconds_positive CHECK (duration_seconds >= 0)
);

CREATE TABLE IF NOT EXISTS crafting_recipe_ingredients (
    id BIGSERIAL PRIMARY KEY,
    recipe_key VARCHAR(64) NOT NULL REFERENCES crafting_recipes(key) ON DELETE CASCADE,
    item_key VARCHAR(64) NOT NULL REFERENCES items(key) ON DELETE RESTRICT,
    quantity INTEGER NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_crafting_recipe_ingredients_quantity_positive CHECK (quantity > 0),
    CONSTRAINT uq_crafting_recipe_ingredients_recipe_item UNIQUE (recipe_key, item_key)
);

CREATE INDEX IF NOT EXISTS idx_crafting_recipes_is_active
ON crafting_recipes(is_active);

CREATE INDEX IF NOT EXISTS idx_crafting_recipe_ingredients_recipe_key
ON crafting_recipe_ingredients(recipe_key);

COMMIT;

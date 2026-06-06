ALTER TABLE gathering_nodes
ADD COLUMN IF NOT EXISTS required_item_key VARCHAR(100);

ALTER TABLE gathering_nodes
ADD COLUMN IF NOT EXISTS required_item_quantity INTEGER NOT NULL DEFAULT 1;

ALTER TABLE gathering_nodes
ADD COLUMN IF NOT EXISTS required_skill_level INTEGER;

ALTER TABLE gathering_nodes
DROP CONSTRAINT IF EXISTS gathering_nodes_required_item_quantity_check;

ALTER TABLE gathering_nodes
ADD CONSTRAINT gathering_nodes_required_item_quantity_check
CHECK (required_item_quantity > 0);

ALTER TABLE gathering_nodes
DROP CONSTRAINT IF EXISTS gathering_nodes_required_skill_level_check;

ALTER TABLE gathering_nodes
ADD CONSTRAINT gathering_nodes_required_skill_level_check
CHECK (required_skill_level IS NULL OR required_skill_level > 0);

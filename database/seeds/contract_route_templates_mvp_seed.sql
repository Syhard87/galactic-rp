BEGIN;

INSERT INTO contract_route_templates (
    key,
    name,
    description,
    item_key,
    item_quantity,
    reward_money,
    pickup_location_key,
    delivery_location_key,
    deadline_seconds,
    is_active
)
VALUES
    ('scrap_to_spatioport', 'Scrap To Spatioport', 'Transporter du scrap au spatioport', 'scrap', 5, 200, 'industrial_zone', 'spatioport', 3600, true),
    ('electronics_to_market', 'Electronics To Market', 'Livrer des composants electroniques au marche central', 'electronic_component', 2, 350, 'industrial_zone', 'market', 3600, true),
    ('medical_to_government', 'Medical To Government', 'Acheminer du materiel medical vers les bureaux gouvernementaux', 'medkit_basic', 1, 250, 'medical_kiosk', 'government_office', 2700, true),
    ('water_to_industrial', 'Water To Industrial', 'Acheminer de leau potable vers la zone industrielle', 'water_bottle', 3, 180, 'market', 'industrial_zone', 1800, true)
ON CONFLICT (key) DO UPDATE
SET
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    item_key = EXCLUDED.item_key,
    item_quantity = EXCLUDED.item_quantity,
    reward_money = EXCLUDED.reward_money,
    pickup_location_key = EXCLUDED.pickup_location_key,
    delivery_location_key = EXCLUDED.delivery_location_key,
    deadline_seconds = EXCLUDED.deadline_seconds,
    is_active = EXCLUDED.is_active,
    updated_at = NOW();

COMMIT;

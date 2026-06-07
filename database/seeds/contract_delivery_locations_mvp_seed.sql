BEGIN;

INSERT INTO contract_delivery_locations (
    key,
    name,
    description,
    location_type,
    position_x,
    position_y,
    position_z,
    radius,
    is_active
)
VALUES
    ('spatioport', 'Spatioport', 'Point de livraison principal du spatioport.', 'spaceport', NULL, NULL, NULL, 500, true),
    ('market', 'Market', 'Point de livraison du marche central.', 'market', NULL, NULL, NULL, 500, true),
    ('industrial_zone', 'Industrial Zone', 'Point de livraison de la zone industrielle.', 'industrial', NULL, NULL, NULL, 500, true),
    ('medical_kiosk', 'Medical Kiosk', 'Point de livraison du kiosque medical.', 'medical', NULL, NULL, NULL, 500, true),
    ('government_office', 'Government Office', 'Point de livraison des bureaux gouvernementaux.', 'government', NULL, NULL, NULL, 500, true)
ON CONFLICT (key) DO UPDATE
SET
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    location_type = EXCLUDED.location_type,
    position_x = EXCLUDED.position_x,
    position_y = EXCLUDED.position_y,
    position_z = EXCLUDED.position_z,
    radius = EXCLUDED.radius,
    is_active = EXCLUDED.is_active,
    updated_at = NOW();

COMMIT;

INSERT INTO crafting_stations (
    key,
    name,
    station_type,
    position_x,
    position_y,
    position_z,
    radius,
    is_active
)
VALUES
    ('medical_workbench', 'Medical Workbench', 'medical_workbench', 0, 0, 100, 300, TRUE),
    ('engineering_bench', 'Engineering Bench', 'engineering_bench', 500, 0, 100, 300, TRUE),
    ('field_camp', 'Field Camp', 'field_camp', -500, 0, 100, 450, TRUE)
ON CONFLICT (key) DO UPDATE
SET
    name = EXCLUDED.name,
    station_type = EXCLUDED.station_type,
    position_x = EXCLUDED.position_x,
    position_y = EXCLUDED.position_y,
    position_z = EXCLUDED.position_z,
    radius = EXCLUDED.radius,
    is_active = EXCLUDED.is_active,
    updated_at = NOW();

INSERT INTO shops (
    key,
    name,
    description,
    shop_type,
    position_x,
    position_y,
    position_z,
    radius,
    requires_proximity,
    is_active
)
VALUES
    ('general_store', 'Magasin general', 'Biens de survie et equipements civils de base', 'general', NULL, NULL, NULL, 250.0, FALSE, TRUE),
    ('medical_kiosk', 'Kiosque medical', 'Consommables de soins et secours legers', 'medical', NULL, NULL, NULL, 250.0, FALSE, TRUE),
    ('tech_vendor', 'Vendeur technologique', 'Equipements utilitaires et communication', 'technology', NULL, NULL, NULL, 250.0, FALSE, TRUE)
ON CONFLICT (key) DO UPDATE
SET
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    shop_type = EXCLUDED.shop_type,
    position_x = EXCLUDED.position_x,
    position_y = EXCLUDED.position_y,
    position_z = EXCLUDED.position_z,
    radius = EXCLUDED.radius,
    requires_proximity = EXCLUDED.requires_proximity,
    is_active = EXCLUDED.is_active,
    updated_at = NOW();

INSERT INTO shop_items (
    shop_id,
    item_key,
    wallet,
    price,
    sell_price,
    is_sellable,
    stock_enabled,
    stock_quantity,
    max_stock,
    is_active
)
SELECT
    shops.id,
    seed.item_key,
    seed.wallet,
    seed.price,
    seed.sell_price,
    seed.is_sellable,
    seed.stock_enabled,
    seed.stock_quantity,
    seed.max_stock,
    seed.is_active
FROM (
    VALUES
        ('general_store', 'ration_pack', 'bank', 20, 10, TRUE, TRUE, 20, 20, TRUE),
        ('general_store', 'id_card', 'bank', 15, NULL, FALSE, FALSE, NULL, NULL, TRUE),
        ('medical_kiosk', 'medkit_basic', 'bank', 45, 25, TRUE, TRUE, 10, 10, TRUE),
        ('tech_vendor', 'comlink', 'bank', 80, 30, TRUE, TRUE, 8, 8, TRUE)
) AS seed(
    shop_key,
    item_key,
    wallet,
    price,
    sell_price,
    is_sellable,
    stock_enabled,
    stock_quantity,
    max_stock,
    is_active
)
JOIN shops
    ON shops.key = seed.shop_key
ON CONFLICT (shop_id, item_key) DO UPDATE
SET
    wallet = EXCLUDED.wallet,
    price = EXCLUDED.price,
    sell_price = EXCLUDED.sell_price,
    is_sellable = EXCLUDED.is_sellable,
    stock_enabled = EXCLUDED.stock_enabled,
    stock_quantity = EXCLUDED.stock_quantity,
    max_stock = EXCLUDED.max_stock,
    is_active = EXCLUDED.is_active,
    updated_at = NOW();

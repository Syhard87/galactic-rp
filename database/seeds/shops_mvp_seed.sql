INSERT INTO shops (key, name, description, shop_type, is_active)
VALUES
    ('general_store', 'Magasin general', 'Biens de survie et equipements civils de base', 'general', TRUE),
    ('medical_kiosk', 'Kiosque medical', 'Consommables de soins et secours legers', 'medical', TRUE),
    ('tech_vendor', 'Vendeur technologique', 'Equipements utilitaires et communication', 'technology', TRUE)
ON CONFLICT (key) DO UPDATE
SET
    name = EXCLUDED.name,
    description = EXCLUDED.description,
    shop_type = EXCLUDED.shop_type,
    is_active = EXCLUDED.is_active,
    updated_at = NOW();

INSERT INTO shop_items (shop_id, item_key, wallet, price, sell_price, is_sellable, is_active)
SELECT
    shops.id,
    seed.item_key,
    seed.wallet,
    seed.price,
    seed.sell_price,
    seed.is_sellable,
    seed.is_active
FROM (
    VALUES
        ('general_store', 'ration_pack', 'bank', 20, 10, TRUE, TRUE),
        ('general_store', 'id_card', 'bank', 15, NULL, FALSE, TRUE),
        ('medical_kiosk', 'medkit_basic', 'bank', 45, 25, TRUE, TRUE),
        ('tech_vendor', 'comlink', 'bank', 80, 30, TRUE, TRUE)
) AS seed(shop_key, item_key, wallet, price, sell_price, is_sellable, is_active)
JOIN shops
    ON shops.key = seed.shop_key
ON CONFLICT (shop_id, item_key) DO UPDATE
SET
    wallet = EXCLUDED.wallet,
    price = EXCLUDED.price,
    sell_price = EXCLUDED.sell_price,
    is_sellable = EXCLUDED.is_sellable,
    is_active = EXCLUDED.is_active,
    updated_at = NOW();

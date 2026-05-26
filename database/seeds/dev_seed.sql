BEGIN;

INSERT INTO players (
    platform_id,
    username
)
VALUES (
    'dev-player-001',
    'dev_test_operator'
)
ON CONFLICT (platform_id) DO UPDATE
SET
    username = EXCLUDED.username,
    last_join_at = NOW(),
    updated_at = NOW();

INSERT INTO characters (
    player_id,
    first_name,
    last_name,
    age,
    species,
    biography,
    money_cash,
    money_bank,
    position_x,
    position_y,
    position_z
)
SELECT
    players.id,
    'Ari',
    'Voss',
    29,
    'Human',
    'Fictional development character used for local database bootstrap.',
    500,
    2500,
    128.0,
    64.0,
    12.0
FROM players
WHERE players.platform_id = 'dev-player-001'
  AND NOT EXISTS (
      SELECT 1
      FROM characters
      WHERE characters.player_id = players.id
        AND characters.first_name = 'Ari'
        AND characters.last_name = 'Voss'
  );

INSERT INTO character_skills (
    character_id,
    skill_key,
    level,
    xp,
    last_gain_at
)
SELECT
    characters.id,
    skills.skill_key,
    skills.level,
    skills.xp,
    NOW()
FROM characters
INNER JOIN players
    ON players.id = characters.player_id
CROSS JOIN (
    VALUES
        ('piloting', 3, 240),
        ('medicine', 2, 110),
        ('engineering', 4, 420)
) AS skills (skill_key, level, xp)
WHERE players.platform_id = 'dev-player-001'
  AND characters.first_name = 'Ari'
  AND characters.last_name = 'Voss'
ON CONFLICT ON CONSTRAINT uq_character_skills_character_skill DO UPDATE
SET
    level = EXCLUDED.level,
    xp = EXCLUDED.xp,
    last_gain_at = EXCLUDED.last_gain_at,
    updated_at = NOW();

COMMIT;

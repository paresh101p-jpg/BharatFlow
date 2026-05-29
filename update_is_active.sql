-- Add is_active column if it doesn't exist
ALTER TABLE leaders_master ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT TRUE;

DROP FUNCTION IF EXISTS get_trending_leaders(integer);
DROP FUNCTION IF EXISTS get_local_leaders(text, text);

-- Update existing RPC: get_trending_leaders
CREATE OR REPLACE FUNCTION get_trending_leaders(days_filter integer)
RETURNS TABLE (
    id uuid,
    name text,
    party text,
    constituency text,
    photo_url text,
    total_likes bigint,
    total_dislikes bigint
) AS $$
BEGIN
    RETURN QUERY
    SELECT lm.id, lm.name, lm.party, lm.constituency, lm.photo_url, lm.total_likes, lm.total_dislikes
    FROM leaders_master lm
    JOIN (
        SELECT leader_id, COUNT(*) as recent_votes
        FROM user_opinions
        WHERE created_at >= NOW() - (days_filter || ' days')::interval
        GROUP BY leader_id
    ) uo ON lm.id = uo.leader_id
    WHERE lm.is_active = TRUE
    ORDER BY uo.recent_votes DESC, lm.total_likes DESC
    LIMIT 20;
END;
$$ LANGUAGE plpgsql;

-- Update existing RPC: get_local_leaders
CREATE OR REPLACE FUNCTION get_local_leaders(user_city text, user_state text)
RETURNS TABLE (
    id uuid,
    name text,
    party text,
    constituency text,
    photo_url text,
    total_likes bigint,
    total_dislikes bigint,
    assets jsonb,
    liabilities jsonb,
    education text,
    criminal_cases integer
) AS $$
BEGIN
    RETURN QUERY
    WITH city_matches AS (
        SELECT * FROM leaders_master
        WHERE constituency ILIKE '%' || user_city || '%' AND is_active = TRUE
        LIMIT 20
    ),
    state_matches AS (
        SELECT * FROM leaders_master
        WHERE constituency ILIKE '%' || user_state || '%'
          AND is_active = TRUE
          AND id NOT IN (SELECT cm.id FROM city_matches cm)
        LIMIT 30
    ),
    random_matches AS (
        SELECT * FROM leaders_master
        WHERE is_active = TRUE
          AND id NOT IN (SELECT cm.id FROM city_matches cm)
          AND id NOT IN (SELECT sm.id FROM state_matches sm)
        LIMIT 50
    )
    SELECT * FROM (
        SELECT * FROM city_matches
        UNION ALL
        SELECT * FROM state_matches
        UNION ALL
        SELECT * FROM random_matches
    ) combined
    LIMIT 50;
END;
$$ LANGUAGE plpgsql;

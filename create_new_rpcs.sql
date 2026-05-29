-- 1. Get Local Leaders RPC
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
        WHERE constituency ILIKE '%' || user_city || '%'
        LIMIT 20
    ),
    state_matches AS (
        SELECT * FROM leaders_master
        WHERE constituency ILIKE '%' || user_state || '%'
          AND id NOT IN (SELECT cm.id FROM city_matches cm)
        LIMIT 30
    ),
    random_matches AS (
        SELECT * FROM leaders_master
        WHERE id NOT IN (SELECT cm.id FROM city_matches cm)
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

-- 2. Toggle Vote RPC
CREATE OR REPLACE FUNCTION toggle_vote(p_leader_id uuid, p_vote_type text)
RETURNS void AS $$
DECLARE
    v_user_id uuid;
    v_existing_vote text;
BEGIN
    v_user_id := auth.uid();
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    -- Check if vote exists
    SELECT vote INTO v_existing_vote
    FROM user_opinions
    WHERE user_id = v_user_id AND leader_id = p_leader_id;

    IF v_existing_vote = p_vote_type THEN
        -- Same vote clicked, remove it
        DELETE FROM user_opinions
        WHERE user_id = v_user_id AND leader_id = p_leader_id;
    ELSE
        -- Different vote or new vote, upsert
        INSERT INTO user_opinions (user_id, leader_id, vote)
        VALUES (v_user_id, p_leader_id, p_vote_type)
        ON CONFLICT (user_id, leader_id)
        DO UPDATE SET vote = p_vote_type, updated_at = NOW();
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

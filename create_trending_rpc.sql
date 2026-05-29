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
    SELECT 
        lm.id,
        lm.name,
        lm.party,
        lm.constituency,
        lm.photo_url,
        COUNT(uo.id) FILTER (WHERE uo.vote = 'LIKE')::bigint AS total_likes,
        COUNT(uo.id) FILTER (WHERE uo.vote = 'DISLIKE')::bigint AS total_dislikes
    FROM leaders_master lm
    JOIN user_opinions uo ON uo.leader_id = lm.id
    WHERE uo.created_at >= NOW() - (days_filter || ' days')::INTERVAL
    GROUP BY lm.id
    ORDER BY total_likes DESC
    LIMIT 10;
END;
$$ LANGUAGE plpgsql;

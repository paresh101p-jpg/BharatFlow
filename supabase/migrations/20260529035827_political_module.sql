-- Political Module Tables and Triggers

-- 1. Create leaders_master table
CREATE TABLE public.leaders_master (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    party TEXT NOT NULL,
    constituency TEXT NOT NULL,
    photo_url TEXT,
    assets JSONB,
    liabilities JSONB,
    education TEXT,
    criminal_cases INT DEFAULT 0,
    total_likes BIGINT DEFAULT 0,
    total_dislikes BIGINT DEFAULT 0,
    search_vector TSVECTOR,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Generate TSVECTOR for global search
CREATE OR REPLACE FUNCTION generate_leader_search_vector() RETURNS trigger AS $$
BEGIN
  NEW.search_vector :=
    setweight(to_tsvector('english', coalesce(NEW.name, '')), 'A') ||
    setweight(to_tsvector('english', coalesce(NEW.party, '')), 'B') ||
    setweight(to_tsvector('english', coalesce(NEW.constituency, '')), 'C');
  RETURN NEW;
END
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_leader_search_vector
BEFORE INSERT OR UPDATE ON public.leaders_master
FOR EACH ROW EXECUTE FUNCTION generate_leader_search_vector();

-- 2. Create user_opinions table
CREATE TYPE vote_type AS ENUM ('LIKE', 'DISLIKE');

CREATE TABLE public.user_opinions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    leader_id UUID NOT NULL REFERENCES public.leaders_master(id) ON DELETE CASCADE,
    vote vote_type NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, leader_id) -- Anti-spam constraint
);

-- 3. 7-Day Vote Lock Trigger
CREATE OR REPLACE FUNCTION enforce_7_day_vote_lock()
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'UPDATE') THEN
        IF (NEW.vote != OLD.vote) AND (NOW() - OLD.updated_at < interval '7 days') THEN
            RAISE EXCEPTION 'VOTE_LOCKED: You can only change your vote once every 7 days.';
        END IF;
    END IF;
    
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER check_vote_lock
BEFORE UPDATE ON public.user_opinions
FOR EACH ROW EXECUTE FUNCTION enforce_7_day_vote_lock();

-- 4. Fast Cache Counter Trigger
CREATE OR REPLACE FUNCTION update_leader_vote_counts()
RETURNS TRIGGER AS $$
BEGIN
    -- Handle new vote
    IF (TG_OP = 'INSERT') THEN
        IF NEW.vote = 'LIKE' THEN
            UPDATE public.leaders_master SET total_likes = total_likes + 1 WHERE id = NEW.leader_id;
        ELSIF NEW.vote = 'DISLIKE' THEN
            UPDATE public.leaders_master SET total_dislikes = total_dislikes + 1 WHERE id = NEW.leader_id;
        END IF;
    
    -- Handle vote change
    ELSIF (TG_OP = 'UPDATE') THEN
        IF NEW.vote = 'LIKE' AND OLD.vote = 'DISLIKE' THEN
            UPDATE public.leaders_master SET total_likes = total_likes + 1, total_dislikes = total_dislikes - 1 WHERE id = NEW.leader_id;
        ELSIF NEW.vote = 'DISLIKE' AND OLD.vote = 'LIKE' THEN
            UPDATE public.leaders_master SET total_likes = total_likes - 1, total_dislikes = total_dislikes + 1 WHERE id = NEW.leader_id;
        END IF;
        
    -- Handle deleted vote
    ELSIF (TG_OP = 'DELETE') THEN
        IF OLD.vote = 'LIKE' THEN
            UPDATE public.leaders_master SET total_likes = total_likes - 1 WHERE id = OLD.leader_id;
        ELSIF OLD.vote = 'DISLIKE' THEN
            UPDATE public.leaders_master SET total_dislikes = total_dislikes - 1 WHERE id = OLD.leader_id;
        END IF;
    END IF;

    RETURN NULL; -- AFTER triggers can return NULL
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER track_vote_counts
AFTER INSERT OR UPDATE OR DELETE ON public.user_opinions
FOR EACH ROW EXECUTE FUNCTION update_leader_vote_counts();

-- 1. Create Parties Master Table
CREATE TABLE IF NOT EXISTS public.parties_master (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    name VARCHAR(255) NOT NULL UNIQUE,
    logo_url TEXT,
    total_likes INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. Create User Party Votes Table (To enforce 1-month lock)
CREATE TABLE IF NOT EXISTS public.user_party_votes (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    party_id UUID REFERENCES public.parties_master(id) ON DELETE CASCADE,
    voted_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id) -- A user can only have one active vote at a time across all parties
);

-- 3. Insert Major Indian Political Parties
INSERT INTO public.parties_master (name, logo_url, total_likes) VALUES
('Bharatiya Janata Party (BJP)', 'https://upload.wikimedia.org/wikipedia/commons/thumb/1/1e/Bharatiya_Janata_Party_logo.svg/240px-Bharatiya_Janata_Party_logo.svg.png', 500),
('Indian National Congress (INC)', 'https://upload.wikimedia.org/wikipedia/commons/thumb/6/63/Indian_National_Congress_hand_logo.svg/240px-Indian_National_Congress_hand_logo.svg.png', 400),
('Aam Aadmi Party (AAP)', 'https://upload.wikimedia.org/wikipedia/commons/thumb/4/4e/Aam_Aadmi_Party_logo_%282017%29.svg/240px-Aam_Aadmi_Party_logo_%282017%29.svg.png', 300),
('All India Trinamool Congress (TMC)', 'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c0/All_India_Trinamool_Congress_flag.svg/240px-All_India_Trinamool_Congress_flag.svg.png', 200),
('Bahujan Samaj Party (BSP)', 'https://upload.wikimedia.org/wikipedia/commons/thumb/d/d2/Elephant_Bahujan_Samaj_Party.svg/240px-Elephant_Bahujan_Samaj_Party.svg.png', 100),
('Samajwadi Party (SP)', 'https://upload.wikimedia.org/wikipedia/commons/thumb/0/07/Samajwadi_Party_Flag.svg/240px-Samajwadi_Party_Flag.svg.png', 80),
('Shiv Sena', 'https://upload.wikimedia.org/wikipedia/commons/thumb/5/52/Bow_and_Arrow_Symbol.svg/240px-Bow_and_Arrow_Symbol.svg.png', 75),
('Nationalist Congress Party (NCP)', 'https://upload.wikimedia.org/wikipedia/commons/thumb/8/87/Nationalist_Congress_Party_Flag.svg/240px-Nationalist_Congress_Party_Flag.svg.png', 70),
('Janata Dal (United) - JD(U)', 'https://upload.wikimedia.org/wikipedia/commons/thumb/1/1a/Arrow_Election_Symbol.svg/240px-Arrow_Election_Symbol.svg.png', 65),
('Rashtriya Janata Dal (RJD)', 'https://upload.wikimedia.org/wikipedia/commons/thumb/0/03/Lantern_symbol.svg/240px-Lantern_symbol.svg.png', 60),
('Dravida Munnetra Kazhagam (DMK)', 'https://upload.wikimedia.org/wikipedia/commons/thumb/a/a8/DMK_flag.svg/240px-DMK_flag.svg.png', 90),
('All India Anna Dravida Munnetra Kazhagam (AIADMK)', 'https://upload.wikimedia.org/wikipedia/commons/thumb/5/5f/AIADMK_flag.svg/240px-AIADMK_flag.svg.png', 85),
('Yuvajana Sramika Rythu Congress Party (YSRCP)', 'https://upload.wikimedia.org/wikipedia/commons/thumb/7/7b/YSR_Congress_Party_Flag.svg/240px-YSR_Congress_Party_Flag.svg.png', 75),
('Telugu Desam Party (TDP)', 'https://upload.wikimedia.org/wikipedia/commons/thumb/2/22/TDP_Flag.svg/240px-TDP_Flag.svg.png', 70),
('Biju Janata Dal (BJD)', 'https://upload.wikimedia.org/wikipedia/commons/thumb/3/30/Conch_shell_symbol.svg/240px-Conch_shell_symbol.svg.png', 50),
('Communist Party of India (Marxist) - CPI(M)', 'https://upload.wikimedia.org/wikipedia/commons/thumb/5/54/CPIM_flag.svg/240px-CPIM_flag.svg.png', 40),
('National People''s Party (NPP)', 'https://upload.wikimedia.org/wikipedia/commons/thumb/0/0e/National_Peoples_Party_Flag.svg/240px-National_Peoples_Party_Flag.svg.png', 20)
ON CONFLICT (name) DO NOTHING;

-- 4. Create RPC function for casting a party vote (with 30 days lock)
CREATE OR REPLACE FUNCTION cast_party_vote(p_party_id UUID)
RETURNS VOID AS $$
DECLARE
    v_last_vote_time TIMESTAMP WITH TIME ZONE;
    v_old_party_id UUID;
BEGIN
    -- Check if user already voted in the last 30 days
    SELECT voted_at, party_id INTO v_last_vote_time, v_old_party_id
    FROM public.user_party_votes
    WHERE user_id = auth.uid();

    IF v_last_vote_time IS NOT NULL THEN
        -- If 30 days haven't passed, throw an error
        IF (NOW() - v_last_vote_time) < INTERVAL '30 days' THEN
            RAISE EXCEPTION 'VOTE_LOCKED_30_DAYS';
        END IF;

        -- If 30 days passed, we can change the vote. First decrement the old party.
        IF v_old_party_id IS NOT NULL THEN
            UPDATE public.parties_master
            SET total_likes = GREATEST(0, total_likes - 1)
            WHERE id = v_old_party_id;
        END IF;
        
        -- Update the record with new party and new timestamp
        UPDATE public.user_party_votes
        SET party_id = p_party_id, voted_at = NOW()
        WHERE user_id = auth.uid();
    ELSE
        -- First time voting
        INSERT INTO public.user_party_votes (user_id, party_id, voted_at)
        VALUES (auth.uid(), p_party_id, NOW());
    END IF;

    -- Increment the new party's vote count
    UPDATE public.parties_master
    SET total_likes = total_likes + 1
    WHERE id = p_party_id;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

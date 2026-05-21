-- 1. Create Helpline Questions Table
CREATE TABLE IF NOT EXISTS helpline_questions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    user_name TEXT NOT NULL,
    user_avatar TEXT,
    user_city TEXT,
    user_state TEXT,
    category TEXT NOT NULL,
    question_text TEXT NOT NULL,
    image_url TEXT,
    voice_url TEXT,
    status TEXT DEFAULT 'Pending', -- 'Pending' or 'Replied'
    is_public BOOLEAN DEFAULT TRUE,
    answer_text TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    replied_at TIMESTAMP WITH TIME ZONE
);

-- Enable RLS
ALTER TABLE helpline_questions ENABLE ROW LEVEL SECURITY;

-- 2. Create Row Level Security (RLS) Policies
-- Policy A: Everyone can read Replied, Public questions (Community Forum)
CREATE POLICY helpline_read_public_policy ON helpline_questions
    FOR SELECT
    USING (is_public = TRUE AND status = 'Replied');

-- Policy B: Logged-in users can read their own questions (My Questions)
CREATE POLICY helpline_read_own_policy ON helpline_questions
    FOR SELECT
    USING (auth.uid() = user_id);

-- Policy C: Logged-in users can insert their own questions
CREATE POLICY helpline_insert_own_policy ON helpline_questions
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- Policy D: Logged-in users can delete their own questions (if they want to revoke)
CREATE POLICY helpline_delete_own_policy ON helpline_questions
    FOR DELETE
    USING (auth.uid() = user_id);

-- Policy E: Logged-in users can update their own questions (before reply)
CREATE POLICY helpline_update_own_policy ON helpline_questions
    FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id AND status = 'Pending');

-- Policy F: Allow anonymous SELECT by ID for the Expert Portal (needed to view pending questions)
CREATE POLICY helpline_anonymous_select ON helpline_questions
    FOR SELECT
    USING (true);

-- Policy G: Allow anonymous UPDATE by ID for the Expert Portal (needed to submit answers/rejections)
CREATE POLICY helpline_anonymous_update ON helpline_questions
    FOR UPDATE
    USING (true)
    WITH CHECK (true);

-- 3. Trigger for Auto-Pruning rows older than 365 days
-- We also implement client-side pruning during fetch as a zero-cost fallback,
-- but having a database-level function is extremely robust.
CREATE OR REPLACE FUNCTION delete_old_helpline_questions()
RETURNS trigger AS $$
BEGIN
    DELETE FROM helpline_questions WHERE created_at < NOW() - INTERVAL '365 days';
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Run pruning trigger whenever a new question is inserted (distributed pruning)
CREATE OR REPLACE TRIGGER prune_old_questions_trigger
AFTER INSERT ON helpline_questions
FOR EACH STATEMENT
EXECUTE FUNCTION delete_old_helpline_questions();

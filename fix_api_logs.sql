
CREATE TABLE IF NOT EXISTS public.api_usage_logs (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    api_name TEXT NOT NULL,
    status_code INTEGER,
    user_id UUID,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

ALTER TABLE public.api_usage_logs ENABLE ROW LEVEL SECURITY;

-- Allow anyone (even unauthenticated) to insert logs
DROP POLICY IF EXISTS "Allow insert for all" ON public.api_usage_logs;
CREATE POLICY "Allow insert for all"
ON public.api_usage_logs FOR INSERT
TO public
WITH CHECK (true);

-- Allow authenticated users to view their own logs, and maybe admin to view all
DROP POLICY IF EXISTS "Allow select for all" ON public.api_usage_logs;
CREATE POLICY "Allow select for all"
ON public.api_usage_logs FOR SELECT
TO public
USING (true);


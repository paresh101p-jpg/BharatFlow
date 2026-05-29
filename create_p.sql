CREATE POLICY helpline_read_public_policy ON public.helpline_questions FOR SELECT USING (is_public = TRUE AND status IN ('Replied', 'Approved'));

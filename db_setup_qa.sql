DO $$ 
BEGIN 
  ALTER TABLE public.helpline_questions ADD COLUMN IF NOT EXISTS views_count INTEGER DEFAULT 0; 
  ALTER TABLE public.helpline_questions ADD COLUMN IF NOT EXISTS rejection_reason TEXT; 
  
  ALTER TABLE public.helpline_answers DROP CONSTRAINT IF EXISTS helpline_answers_question_id_fkey; 
  ALTER TABLE public.helpline_answers ADD CONSTRAINT helpline_answers_question_id_fkey FOREIGN KEY (question_id) REFERENCES public.helpline_questions(id) ON DELETE CASCADE; 
  
  PERFORM cron.schedule('delete-old-qa', '0 0 * * *', 'DELETE FROM public.helpline_questions WHERE created_at < NOW() - INTERVAL ''365 days'''); 
END $$;

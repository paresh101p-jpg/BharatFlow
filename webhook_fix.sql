DROP TRIGGER IF EXISTS qa_notify ON public.helpline_questions;
CREATE TRIGGER qa_notify AFTER INSERT ON public.helpline_questions FOR EACH ROW EXECUTE FUNCTION supabase_functions.http_request('https://wkhelvyqudzyzbrayyqo.supabase.co/functions/v1/question_approval', 'POST', '{"Content-Type": "application/json"}', '{}', '1000');

DROP TRIGGER IF EXISTS qa_fcm_notify ON public.helpline_answers;
CREATE TRIGGER qa_fcm_notify AFTER INSERT ON public.helpline_answers FOR EACH ROW EXECUTE FUNCTION supabase_functions.http_request('https://wkhelvyqudzyzbrayyqo.supabase.co/functions/v1/send_fcm', 'POST', '{"Content-Type": "application/json"}', '{}', '1000');

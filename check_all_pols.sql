SELECT polname, polcmd, pg_get_expr(polqual, polrelid) as condition FROM pg_policy WHERE polrelid = 'helpline_questions'::regclass;

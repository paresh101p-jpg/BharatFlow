SELECT pg_get_functiondef(oid) FROM pg_proc WHERE proname = 'http_request' AND pronamespace = (SELECT oid FROM pg_namespace WHERE nspname = 'supabase_functions');

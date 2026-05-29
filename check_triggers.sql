SELECT pg_get_triggerdef(oid) FROM pg_trigger WHERE tgname = 'qa_notify';

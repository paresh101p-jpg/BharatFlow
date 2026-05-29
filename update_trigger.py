import psycopg2
import sys

host = "aws-1-ap-south-1.pooler.supabase.com"
port = 5432
dbname = "postgres"
user = "postgres.wkhelvyqudzyzbrayyqo"
password = "g?d5BzZ*/+ExQ*2"

try:
    print("Connecting to database...")
    conn = psycopg2.connect(host=host, port=port, dbname=dbname, user=user, password=password)
    conn.autocommit = True
    cursor = conn.cursor()

    sql = """
    CREATE OR REPLACE FUNCTION check_vote_timeout()
    RETURNS trigger AS $$
    BEGIN
        IF (TG_OP = 'UPDATE' OR TG_OP = 'DELETE') THEN
            IF (NOW() - OLD.updated_at) < INTERVAL '7 days' THEN
                RAISE EXCEPTION 'VOTE_LOCKED';
            END IF;
            IF (TG_OP = 'UPDATE') THEN
                NEW.updated_at = NOW();
                RETURN NEW;
            END IF;
            IF (TG_OP = 'DELETE') THEN
                RETURN OLD;
            END IF;
        END IF;
        RETURN NEW;
    END;
    $$ LANGUAGE plpgsql;

    DROP TRIGGER IF EXISTS enforce_vote_timeout ON public.user_opinions;
    CREATE TRIGGER enforce_vote_timeout
    BEFORE UPDATE OR DELETE ON public.user_opinions
    FOR EACH ROW
    EXECUTE FUNCTION check_vote_timeout();
    """

    cursor.execute(sql)
    print("Trigger updated successfully!")

except Exception as e:
    print(f"Error: {e}")
    sys.exit(1)

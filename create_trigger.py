import psycopg2
import sys

host = "aws-1-ap-south-1.pooler.supabase.com"
port = 5432
dbname = "postgres"
user = "postgres.wkhelvyqudzyzbrayyqo"
password = "g?d5BzZ*/+ExQ*2"

sql = """
CREATE TRIGGER notify_new_leader_fcm
AFTER INSERT ON public.leaders_master
FOR EACH ROW
EXECUTE FUNCTION supabase_functions.http_request(
    'https://wkhelvyqudzyzbrayyqo.supabase.co/functions/v1/notify_new_leader',
    'POST',
    '{"Content-Type": "application/json"}',
    '{}',
    '1000'
);
"""

try:
    print(f"Connecting to database...")
    conn = psycopg2.connect(host=host, port=port, dbname=dbname, user=user, password=password)
    conn.autocommit = True
    cursor = conn.cursor()
    
    print("Executing SQL...")
    cursor.execute(sql)
    print("Trigger created successfully!")
    
    cursor.close()
    conn.close()
except Exception as e:
    print(f"Error: {e}")
    sys.exit(1)

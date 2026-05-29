import psycopg2
import sys

host = "aws-1-ap-south-1.pooler.supabase.com"
port = 5432
dbname = "postgres"
user = "postgres.wkhelvyqudzyzbrayyqo"
password = "g?d5BzZ*/+ExQ*2"

try:
    print(f"Connecting to database to reset fake votes...")
    conn = psycopg2.connect(host=host, port=port, dbname=dbname, user=user, password=password)
    conn.autocommit = True
    cursor = conn.cursor()
    
    print("Resetting all likes and dislikes to 0...")
    sql = "UPDATE public.leaders_master SET total_likes = 0, total_dislikes = 0;"
    cursor.execute(sql)
    
    print("Fake votes removed. Data is now clean and real.")
    
    cursor.close()
    conn.close()
except Exception as e:
    print(f"Error: {e}")
    sys.exit(1)

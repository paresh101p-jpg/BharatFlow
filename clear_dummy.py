import psycopg2
import sys

host = "aws-1-ap-south-1.pooler.supabase.com"
port = 5432
dbname = "postgres"
user = "postgres.wkhelvyqudzyzbrayyqo"
password = "g?d5BzZ*/+ExQ*2"

try:
    print("Clearing dummy data...")
    conn = psycopg2.connect(host=host, port=port, dbname=dbname, user=user, password=password)
    conn.autocommit = True
    cursor = conn.cursor()
    
    sql = "UPDATE public.leaders_master SET assets=NULL, liabilities=NULL, education=NULL, criminal_cases=NULL"
    cursor.execute(sql)
    
    print("Dummy stats cleared successfully!")
    cursor.close()
    conn.close()

except Exception as e:
    print(f"Error: {e}")
    sys.exit(1)

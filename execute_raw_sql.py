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
    
    with open('create_comments_table.sql', 'r') as f:
        sql = f.read()
        
    cursor.execute(sql)
    print("Comments table and policies created successfully!")

except Exception as e:
    print(f"Error: {e}")
    sys.exit(1)

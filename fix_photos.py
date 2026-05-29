import psycopg2
import sys

host = "aws-1-ap-south-1.pooler.supabase.com"
port = 5432
dbname = "postgres"
user = "postgres.wkhelvyqudzyzbrayyqo"
password = "g?d5BzZ*/+ExQ*2"

try:
    print(f"Connecting to database to fix photos...")
    conn = psycopg2.connect(host=host, port=port, dbname=dbname, user=user, password=password)
    conn.autocommit = True
    cursor = conn.cursor()
    
    print("Updating photo_url to use UI Avatars...")
    sql = """
    UPDATE public.leaders_master 
    SET photo_url = 'https://ui-avatars.com/api/?name=' || REPLACE(name, ' ', '+') || '&background=random&color=fff&size=200'
    """
    cursor.execute(sql)
    
    print("Photos updated successfully!")
    
    cursor.close()
    conn.close()
except Exception as e:
    print(f"Error: {e}")
    sys.exit(1)

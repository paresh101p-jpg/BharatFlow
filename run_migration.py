import psycopg2
import sys

host = "aws-1-ap-south-1.pooler.supabase.com"
port = 5432
dbname = "postgres"
user = "postgres.wkhelvyqudzyzbrayyqo"
password = "g?d5BzZ*/+ExQ*2"
migration_file = "supabase/migrations/20260529035827_political_module.sql"

try:
    print(f"Connecting to database...")
    conn = psycopg2.connect(host=host, port=port, dbname=dbname, user=user, password=password)
    conn.autocommit = True
    cursor = conn.cursor()
    
    print(f"Reading migration file: {migration_file}")
    with open(migration_file, 'r', encoding='utf-8') as f:
        sql = f.read()
        
    print("Executing SQL...")
    cursor.execute(sql)
    print("Migration executed successfully!")
    
    # Insert some dummy candidates
    print("Inserting dummy candidates...")
    dummy_sql = """
    INSERT INTO public.leaders_master (name, party, constituency, total_likes, total_dislikes, photo_url, assets, criminal_cases)
    VALUES 
    ('Narendra Modi', 'BJP', 'Varanasi', 1500000, 200000, 'https://upload.wikimedia.org/wikipedia/commons/8/80/Prime_Minister_Shri_Narendra_Modi_in_New_Delhi_on_August_08%2C_2019_%28cropped%29.jpg', '{"total": "2.85 Crore"}', 0),
    ('Rahul Gandhi', 'INC', 'Wayanad', 850000, 320000, 'https://upload.wikimedia.org/wikipedia/commons/5/5f/Rahul_Gandhi_Waynad_2024.jpg', '{"total": "20 Crore"}', 0),
    ('Arvind Kejriwal', 'AAP', 'New Delhi', 500000, 100000, 'https://upload.wikimedia.org/wikipedia/commons/e/e0/Arvind_Kejriwal.jpg', '{"total": "3.4 Crore"}', 0)
    ON CONFLICT DO NOTHING;
    """
    cursor.execute(dummy_sql)
    print("Dummy data inserted!")
    
    cursor.close()
    conn.close()
except Exception as e:
    print(f"Error: {e}")
    sys.exit(1)

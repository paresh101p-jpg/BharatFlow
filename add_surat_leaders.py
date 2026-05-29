import psycopg2
import sys

host = "aws-1-ap-south-1.pooler.supabase.com"
port = 5432
dbname = "postgres"
user = "postgres.wkhelvyqudzyzbrayyqo"
password = "g?d5BzZ*/+ExQ*2"

additional_leaders = [
    ("Harsh Sanghavi", "BJP", "Majura (Surat)", '{"total": "15 Crore"}', 0),
    ("C. R. Patil", "BJP", "Navsari (Near Surat)", '{"total": "40 Crore"}', 1),
    ("Bhupendra Patel", "BJP", "Ghatlodia (Ahmedabad)", '{"total": "8 Crore"}', 0),
    ("Amit Shah", "BJP", "Gandhinagar", '{"total": "35 Crore"}', 2),
    ("Mamata Banerjee", "AITC", "Bhabanipur (Kolkata)", '{"total": "1.5 Crore"}', 0),
    ("Yogi Adityanath", "BJP", "Gorakhpur Urban", '{"total": "1 Crore"}', 0),
]

try:
    print(f"Connecting to database to add more leaders...")
    conn = psycopg2.connect(host=host, port=port, dbname=dbname, user=user, password=password)
    conn.autocommit = True
    cursor = conn.cursor()
    
    print("Inserting more dummy data for testing...")
    for name, party, const, assets, crime in additional_leaders:
        sql = """
        INSERT INTO public.leaders_master (name, party, constituency, assets, criminal_cases)
        VALUES (%s, %s, %s, %s::jsonb, %s)
        """
        cursor.execute(sql, (name, party, const, assets, crime))
        
    print("Additional dummy leaders inserted!")
    
    cursor.close()
    conn.close()
except Exception as e:
    print(f"Error: {e}")
    sys.exit(1)

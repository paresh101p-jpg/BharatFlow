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
    
    # Create Table
    cursor.execute("""
        CREATE TABLE IF NOT EXISTS public.election_calendar (
            id SERIAL PRIMARY KEY,
            state_name TEXT NOT NULL,
            election_type TEXT NOT NULL,
            expected_date TEXT NOT NULL,
            status TEXT NOT NULL,
            created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
        );
    """)
    
    # Clear existing data to avoid duplicates on re-runs
    cursor.execute("TRUNCATE TABLE public.election_calendar;")
    
    # Insert Data (Based on current real-world upcoming elections)
    elections = [
        ('Haryana', 'Assembly Election', 'Oct-Nov 2024', 'Upcoming'),
        ('Maharashtra', 'Assembly Election', 'Oct-Nov 2024', 'Upcoming'),
        ('Jharkhand', 'Assembly Election', 'Nov-Dec 2024', 'Upcoming'),
        ('Delhi', 'Assembly Election', 'Feb 2025', 'Upcoming'),
        ('Bihar', 'Assembly Election', 'Oct-Nov 2025', 'Upcoming'),
        ('West Bengal', 'Assembly Election', 'April-May 2026', 'Upcoming'),
        ('Tamil Nadu', 'Assembly Election', 'April-May 2026', 'Upcoming'),
        ('Kerala', 'Assembly Election', 'April-May 2026', 'Upcoming'),
        ('Assam', 'Assembly Election', 'April-May 2026', 'Upcoming'),
        ('Uttar Pradesh', 'Assembly Election', 'Feb-Mar 2027', 'Upcoming'),
        ('Gujarat', 'Assembly Election', 'Dec 2027', 'Upcoming'),
    ]
    
    for state, e_type, e_date, status in elections:
        cursor.execute("""
            INSERT INTO public.election_calendar (state_name, election_type, expected_date, status)
            VALUES (%s, %s, %s, %s)
        """, (state, e_type, e_date, status))
        
    print("Election calendar populated successfully!")
    
    # Set public access policy
    try:
        cursor.execute("ALTER TABLE public.election_calendar ENABLE ROW LEVEL SECURITY;")
        cursor.execute("DROP POLICY IF EXISTS \"Enable read access for all users\" ON public.election_calendar;")
        cursor.execute("""
            CREATE POLICY "Enable read access for all users" 
            ON public.election_calendar FOR SELECT USING (true);
        """)
    except Exception as e:
        print(f"Policy warning: {e}")

    cursor.close()
    conn.close()

except Exception as e:
    print(f"Error: {e}")
    sys.exit(1)

import pandas as pd
import psycopg2
import requests
import io
import sys

host = "aws-1-ap-south-1.pooler.supabase.com"
port = 5432
dbname = "postgres"
user = "postgres.wkhelvyqudzyzbrayyqo"
password = "g?d5BzZ*/+ExQ*2"

try:
    print("Fetching All India MPs data from Wikipedia...")
    url = "https://en.wikipedia.org/wiki/List_of_members_of_the_18th_Lok_Sabha"
    headers = {'User-Agent': 'Mozilla/5.0'}
    response = requests.get(url, headers=headers)
    response.raise_for_status()
    
    tables = pd.read_html(io.StringIO(response.text))
    
    print("Connecting to database...")
    conn = psycopg2.connect(host=host, port=port, dbname=dbname, user=user, password=password)
    conn.autocommit = True
    cursor = conn.cursor()
    
    count = 0
    # Process tables 0 to 35 (which represent states/UTs)
    for tbl in tables:
        if 'Constituency' in tbl.columns and 'Name' in tbl.columns and 'Party' in tbl.columns:
            for index, row in tbl.iterrows():
                name = str(row.get('Name', '')).split('[')[0].strip()
                party = str(row.get('Party', '')).split('[')[0].strip()
                constituency = str(row.get('Constituency', '')).strip()
                
                if name and party and name != 'nan' and name.lower() != 'vacant':
                    # Insert into database
                    sql = """
                    INSERT INTO public.leaders_master (name, party, constituency, photo_url)
                    VALUES (%s, %s, %s, %s)
                    ON CONFLICT DO NOTHING;
                    """
                    photo_url = f"https://ui-avatars.com/api/?name={name.replace(' ', '+')}&background=random&color=fff&size=200"
                    cursor.execute(sql, (name, party, constituency, photo_url))
                    count += 1
            
    print(f"Successfully inserted {count} All India MPs into the live database!")
    cursor.close()
    conn.close()

except Exception as e:
    print(f"Error: {e}")
    sys.exit(1)

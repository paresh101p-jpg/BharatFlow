import psycopg2
import sys
import json

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
    
    # Manually updating Harsh Sanghavi based on public 2022 affidavit info
    hs_edu = "10th Pass (S.S.C from Sharirik Shikshan Vidyalaya, Surat)"
    hs_assets = {"total": "17 Crore+", "details": "Self-acquired and inherited properties, business investments."}
    hs_liab = {"total": "1.5 Crore+", "details": "Loans and dues"}
    
    # Manually updating Amit Shah based on public 2024 affidavit info
    as_edu = "B.Sc (Second Year) from C.U. Shah Science College, Ahmedabad"
    as_assets = {"total": "36 Crore+", "details": "Real estate, inherited wealth, investments."}
    as_liab = {"total": "15 Lacs", "details": "Minor liabilities"}
    
    cursor.execute("""
        UPDATE public.leaders_master 
        SET education = %s, assets = %s, liabilities = %s 
        WHERE name ILIKE '%%Harsh Sanghavi%%'
    """, (hs_edu, json.dumps(hs_assets), json.dumps(hs_liab)))

    cursor.execute("""
        UPDATE public.leaders_master 
        SET education = %s, assets = %s, liabilities = %s 
        WHERE name ILIKE '%%Amit Shah%%'
    """, (as_edu, json.dumps(as_assets), json.dumps(as_liab)))
    
    # Yogi Adityanath
    ya_edu = "B.Sc (Mathematics) from H.N.B. Garhwal University"
    ya_assets = {"total": "1.5 Crore+", "details": "Bank balance, vehicles, no immovable property"}
    ya_liab = {"total": "0", "details": "No liabilities"}
    cursor.execute("""
        UPDATE public.leaders_master 
        SET education = %s, assets = %s, liabilities = %s 
        WHERE name ILIKE '%%Yogi Adityanath%%'
    """, (ya_edu, json.dumps(ya_assets), json.dumps(ya_liab)))
    
    print("Successfully updated top leaders!")

except Exception as e:
    print(f"Error: {e}")
    sys.exit(1)

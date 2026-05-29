import pandas as pd
import psycopg2
import requests
import io
import sys
import time

host = "aws-1-ap-south-1.pooler.supabase.com"
port = 5432
dbname = "postgres"
user = "postgres.wkhelvyqudzyzbrayyqo"
password = "g?d5BzZ*/+ExQ*2"

# List of Wikipedia pages for state assemblies (approximations of current ones)
# We use the standard naming conventions. If a page is slightly off, we catch the 404 and continue.
state_assemblies = {
    "Andhra Pradesh": "16th_Andhra_Pradesh_Assembly",
    "Arunachal Pradesh": "8th_Arunachal_Pradesh_Assembly",
    "Assam": "15th_Assam_Assembly",
    "Bihar": "17th_Bihar_Assembly",
    "Chhattisgarh": "6th_Chhattisgarh_Assembly",
    "Delhi": "7th_Delhi_Assembly",
    "Goa": "8th_Goa_Assembly",
    "Gujarat": "15th_Gujarat_Legislative_Assembly",
    "Haryana": "14th_Haryana_Assembly",
    "Himachal Pradesh": "14th_Himachal_Pradesh_Assembly",
    "Jharkhand": "5th_Jharkhand_Assembly",
    "Karnataka": "16th_Karnataka_Assembly",
    "Kerala": "15th_Kerala_Legislative_Assembly",
    "Madhya Pradesh": "16th_Madhya_Pradesh_Assembly",
    "Maharashtra": "14th_Maharashtra_Assembly",
    "Manipur": "12th_Manipur_Assembly",
    "Meghalaya": "11th_Meghalaya_Assembly",
    "Mizoram": "9th_Mizoram_Assembly",
    "Nagaland": "14th_Nagaland_Assembly",
    "Odisha": "17th_Odisha_Assembly",
    "Puducherry": "15th_Puducherry_Assembly",
    "Punjab": "16th_Punjab_Assembly",
    "Rajasthan": "16th_Rajasthan_Assembly",
    "Sikkim": "11th_Sikkim_Assembly",
    "Tamil Nadu": "16th_Tamil_Nadu_Assembly",
    "Telangana": "3rd_Telangana_Assembly",
    "Tripura": "13th_Tripura_Assembly",
    "Uttar Pradesh": "18th_Uttar_Pradesh_Assembly",
    "Uttarakhand": "5th_Uttarakhand_Assembly",
    "West Bengal": "17th_West_Bengal_Assembly"
}

try:
    print("Connecting to database...")
    conn = psycopg2.connect(host=host, port=port, dbname=dbname, user=user, password=password)
    conn.autocommit = True
    cursor = conn.cursor()
    
    headers = {'User-Agent': 'Mozilla/5.0'}
    total_count = 0
    
    for state, wiki_slug in state_assemblies.items():
        print(f"Fetching MLAs for {state}...")
        url = f"https://en.wikipedia.org/wiki/{wiki_slug}"
        try:
            response = requests.get(url, headers=headers)
            if response.status_code != 200:
                print(f"  -> Skipping {state}: Page not found ({response.status_code})")
                continue
                
            tables = pd.read_html(io.StringIO(response.text))
            state_count = 0
            
            # Heuristic to find the table with Members
            for tbl in tables:
                # Normalize column names
                cols = [str(c).lower() for c in tbl.columns]
                
                # We need Constituency and some variation of Name/Member
                if any('constituency' in c for c in cols) and (any('name' in c for c in cols) or any('member' in c for c in cols)):
                    
                    # Find exact column names to extract
                    const_col = next(c for c in tbl.columns if 'constituency' in str(c).lower())
                    name_col = next(c for c in tbl.columns if 'name' in str(c).lower() or 'member' in str(c).lower())
                    party_col = next((c for c in tbl.columns if 'party' in str(c).lower()), None)
                    
                    for index, row in tbl.iterrows():
                        name = str(row.get(name_col, '')).split('[')[0].strip()
                        constituency = str(row.get(const_col, '')).strip()
                        party = str(row.get(party_col, 'Independent')).split('[')[0].strip() if party_col else "Unknown"
                        
                        if name and name.lower() not in ['nan', 'vacant', 'name', 'member']:
                            sql = """
                            INSERT INTO public.leaders_master (name, party, constituency, photo_url)
                            VALUES (%s, %s, %s, %s)
                            ON CONFLICT DO NOTHING;
                            """
                            full_const = f"{constituency} ({state} MLA)"
                            photo_url = f"https://ui-avatars.com/api/?name={name.replace(' ', '+')}&background=random&color=fff&size=200"
                            
                            try:
                                cursor.execute(sql, (name, party, full_const, photo_url))
                                state_count += 1
                            except Exception as db_err:
                                pass
                                
                    # Usually the largest matching table is the correct one, so we don't break immediately, 
                    # but if we found a substantial amount of MLAs (>20), we can assume it's the right table.
                    if state_count > 20:
                        break
                        
            print(f"  -> Inserted {state_count} MLAs for {state}")
            total_count += state_count
            time.sleep(1) # Be polite to Wikipedia
            
        except Exception as e:
            print(f"  -> Error parsing {state}: {e}")
            
    print(f"\nSUCCESS: Inserted a total of {total_count} All India MLAs into the database!")
    cursor.close()
    conn.close()

except Exception as e:
    print(f"Critical Error: {e}")
    sys.exit(1)

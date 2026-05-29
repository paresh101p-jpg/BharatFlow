import psycopg2
import requests
from bs4 import BeautifulSoup
import sys
import time

host = "aws-1-ap-south-1.pooler.supabase.com"
port = 5432
dbname = "postgres"
user = "postgres.wkhelvyqudzyzbrayyqo"
password = "g?d5BzZ*/+ExQ*2"

def get_myneta_data(name):
    # This is a heuristic scraper for MyNeta
    search_url = f"https://myneta.info/search_myneta.php?q={requests.utils.quote(name)}"
    headers = {'User-Agent': 'Mozilla/5.0'}
    
    try:
        res = requests.get(search_url, headers=headers, timeout=5)
        soup = BeautifulSoup(res.text, 'html.parser')
        
        # Find the first link in the search results
        links = soup.find_all('a')
        candidate_url = None
        for link in links:
            if 'candidate.php' in link.get('href', ''):
                candidate_url = link.get('href')
                if not candidate_url.startswith('http'):
                    candidate_url = "https://myneta.info/" + candidate_url
                break
                
        if not candidate_url:
            return None
            
        # Fetch candidate page
        c_res = requests.get(candidate_url, headers=headers, timeout=5)
        c_soup = BeautifulSoup(c_res.text, 'html.parser')
        
        data = {}
        
        # Extract Education
        edu_div = c_soup.find(string=lambda t: t and 'Education:' in t)
        if edu_div:
            data['education'] = edu_div.parent.text.replace('Education:', '').strip()
            
        # Extract Assets
        assets_td = c_soup.find(string=lambda t: t and 'Total Assets' in t)
        if assets_td:
            try:
                asset_val = assets_td.parent.find_next_sibling('td').text.strip()
                data['assets'] = {"total": asset_val, "details": "Data sourced from Election Commission Affidavit via MyNeta."}
            except: pass
            
        # Extract Liabilities
        liab_td = c_soup.find(string=lambda t: t and 'Liabilities' in t)
        if liab_td:
            try:
                liab_val = liab_td.parent.find_next_sibling('td').text.strip()
                data['liabilities'] = {"total": liab_val}
            except: pass
            
        return data if data else None
        
    except Exception as e:
        print(f"Error scraping {name}: {e}")
        return None

try:
    print("Connecting to database...")
    conn = psycopg2.connect(host=host, port=port, dbname=dbname, user=user, password=password)
    conn.autocommit = True
    cursor = conn.cursor()
    
    # We fetch leaders starting with Surat/Gujarat or general top leaders that have empty education
    cursor.execute("SELECT id, name FROM public.leaders_master WHERE education IS NULL OR education = 'N/A' ORDER BY id DESC")
    leaders = cursor.fetchall()
    
    updated_count = 0
    print(f"Found {len(leaders)} leaders to process for MyNeta data.")
    
    for l_id, name in leaders:
        print(f"Fetching MyNeta data for {name}...")
        data = get_myneta_data(name)
        
        if data:
            edu = data.get('education')
            assets = data.get('assets')
            liabilities = data.get('liabilities')
            
            import json
            cursor.execute("""
                UPDATE public.leaders_master 
                SET education = %s, assets = %s, liabilities = %s 
                WHERE id = %s
            """, (edu, json.dumps(assets) if assets else None, json.dumps(liabilities) if liabilities else None, l_id))
            
            updated_count += 1
            print(f" -> Updated {name}")
            
        time.sleep(1) # Be polite to MyNeta servers
            
    print(f"\nSUCCESS: Updated {updated_count} leaders with Real MyNeta data!")
    cursor.close()
    conn.close()

except Exception as e:
    print(f"Critical Error: {e}")
    sys.exit(1)

import requests
from bs4 import BeautifulSoup
from supabase import create_client, Client
import os
import re

# -------------------------------------------------------------
# SETUP INSTRUCTIONS FOR VPS:
# 1. Install required packages: 
#    pip install requests beautifulsoup4 supabase
# 2. Set your Supabase URL and Key as Environment Variables 
#    or replace the placeholder text below.
# 3. Run the script: python3 sync_parties_vps.py
# 4. Set a cron job (e.g. run on 1st Jan every year):
#    0 0 1 1 * /usr/bin/python3 /path/to/sync_parties_vps.py
# -------------------------------------------------------------

# Replace with your actual Supabase URL and Service Role Key
SUPABASE_URL = os.environ.get("SUPABASE_URL", "YOUR_SUPABASE_URL_HERE")
SUPABASE_KEY = os.environ.get("SUPABASE_KEY", "YOUR_SUPABASE_SERVICE_ROLE_KEY_HERE")

try:
    supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)
except Exception as e:
    print(f"Failed to initialize Supabase client: {e}")

def get_parties_from_wikipedia():
    print("Fetching parties from Wikipedia...")
    url = "https://en.wikipedia.org/wiki/List_of_political_parties_in_India"
    headers = {"User-Agent": "Mozilla/5.0"}
    
    try:
        response = requests.get(url, headers=headers)
        response.raise_for_status()
    except Exception as e:
        print(f"Error fetching Wikipedia page: {e}")
        return []

    soup = BeautifulSoup(response.content, 'html.parser')
    parties = []
    
    # Wikipedia stores the parties in tables with class 'wikitable'
    tables = soup.find_all('table', {'class': 'wikitable'})
    
    for table in tables:
        rows = table.find_all('tr')
        for row in rows[1:]: # Skip header row
            cols = row.find_all(['td', 'th'])
            if len(cols) >= 2:
                # Find the party name. It's usually in one of the first few columns inside an <a> tag.
                name_col = cols[1] if len(cols) > 2 else cols[0]
                name_tag = name_col.find('a')
                if not name_tag:
                    name = name_col.text.strip()
                else:
                    name = name_tag.text.strip()
                
                # Cleanup unwanted references like [1], [2]
                name = re.sub(r'\[.*?\]', '', name).strip()
                
                # Filter out garbage data
                if not name or len(name) < 2:
                    continue

                # Find the party logo. It's usually an <img> tag in the row.
                logo_url = None
                img_tag = row.find('img')
                if img_tag and img_tag.has_attr('src'):
                    # Make URL absolute
                    raw_src = img_tag['src']
                    if raw_src.startswith("//"):
                        logo_url = "https:" + raw_src
                    else:
                        logo_url = raw_src
                    
                    # Wikipedia uses thumbnails. We can replace the width to get a slightly better resolution.
                    # Example: /thumb/.../50px-Logo.svg.png -> /thumb/.../240px-Logo.svg.png
                    if "thumb" in logo_url:
                        logo_url = re.sub(r'\d+px-', '240px-', logo_url)
                
                # Basic filter to ensure it sounds like a party
                valid_keywords = ["Party", "Congress", "Morcha", "Dal", "Sena", "Kazhagam", "Samithi", "Front", "League", "All India", "National"]
                is_valid = any(kw in name for kw in valid_keywords)
                
                if is_valid or name.isupper(): # Some abbreviations might be upper case
                    parties.append({
                        "name": name,
                        "logo_url": logo_url
                    })

    # Deduplicate based on party name
    unique_parties = {}
    for p in parties:
        if p['name'] not in unique_parties:
            unique_parties[p['name']] = p
            
    print(f"Successfully scraped {len(unique_parties)} valid parties.")
    return list(unique_parties.values())


def sync_to_supabase(parties_list):
    if not parties_list:
        print("No parties to sync.")
        return
        
    print(f"Syncing to Supabase table 'parties_master'...")
    added_count = 0
    
    for party in parties_list:
        try:
            # Check if party already exists
            existing = supabase.table('parties_master').select('id').eq('name', party['name']).execute()
            
            if not existing.data:
                # If it doesn't exist, insert it
                supabase.table('parties_master').insert({
                    'name': party['name'],
                    'logo_url': party['logo_url'],
                    'total_likes': 0
                }).execute()
                added_count += 1
                print(f"[NEW] Added: {party['name']}")
        except Exception as e:
            print(f"[ERROR] Could not sync {party['name']}: {e}")
            
    print("--------------------------------------------------")
    print(f"SYNC COMPLETE. Added {added_count} new parties.")
    print("--------------------------------------------------")

if __name__ == "__main__":
    if "YOUR_SUPABASE_URL_HERE" in SUPABASE_URL:
        print("ERROR: Please open the script and put your actual Supabase URL and Key.")
    else:
        scraped_parties = get_parties_from_wikipedia()
        sync_to_supabase(scraped_parties)

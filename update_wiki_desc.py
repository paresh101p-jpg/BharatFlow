import psycopg2
import requests
import sys
import time

host = "aws-1-ap-south-1.pooler.supabase.com"
port = 5432
dbname = "postgres"
user = "postgres.wkhelvyqudzyzbrayyqo"
password = "g?d5BzZ*/+ExQ*2"

def get_wiki_desc(name):
    # Query Wikipedia API for the page extract (summary)
    url = f"https://en.wikipedia.org/w/api.php?action=query&titles={requests.utils.quote(name)}&prop=extracts&exintro=true&explaintext=true&exsentences=3&format=json"
    headers = {'User-Agent': 'BharatFlowApp/1.0'}
    try:
        response = requests.get(url, headers=headers, timeout=5)
        data = response.json()
        pages = data.get('query', {}).get('pages', {})
        for page_id, page_info in pages.items():
            if 'extract' in page_info and len(page_info['extract']) > 10:
                return page_info['extract']
    except Exception as e:
        pass
    return None

try:
    print("Connecting to database...")
    conn = psycopg2.connect(host=host, port=port, dbname=dbname, user=user, password=password)
    conn.autocommit = True
    cursor = conn.cursor()
    
    # Fetch for all leaders that don't have descriptions yet
    cursor.execute("SELECT id, name FROM public.leaders_master WHERE description IS NULL")
    leaders = cursor.fetchall()
    
    updated_count = 0
    for idx, (l_id, name) in enumerate(leaders):
        desc = get_wiki_desc(name)
        if desc:
            cursor.execute("UPDATE public.leaders_master SET description = %s WHERE id = %s", (desc, l_id))
            updated_count += 1
        time.sleep(0.1)
            
    print(f"Successfully updated {updated_count} leaders with Wikipedia descriptions!")
    cursor.close()
    conn.close()

except Exception as e:
    print(f"Error: {e}")
    sys.exit(1)

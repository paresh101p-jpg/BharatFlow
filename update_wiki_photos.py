import psycopg2
import requests
import sys
import time

host = "aws-1-ap-south-1.pooler.supabase.com"
port = 5432
dbname = "postgres"
user = "postgres.wkhelvyqudzyzbrayyqo"
password = "g?d5BzZ*/+ExQ*2"

def get_wiki_image(name):
    # Query Wikipedia API for the page image
    url = f"https://en.wikipedia.org/w/api.php?action=query&titles={requests.utils.quote(name)}&prop=pageimages&format=json&pithumbsize=500"
    headers = {'User-Agent': 'BharatFlowApp/1.0 (Contact: admin@bharatflow.com)'}
    try:
        response = requests.get(url, headers=headers, timeout=5)
        data = response.json()
        pages = data.get('query', {}).get('pages', {})
        for page_id, page_info in pages.items():
            if 'thumbnail' in page_info:
                return page_info['thumbnail']['source']
    except Exception as e:
        pass
    return None

try:
    print("Connecting to database...")
    conn = psycopg2.connect(host=host, port=port, dbname=dbname, user=user, password=password)
    conn.autocommit = True
    cursor = conn.cursor()
    
    # Get all leaders
    cursor.execute("SELECT id, name FROM public.leaders_master WHERE photo_url LIKE '%ui-avatars%'")
    leaders = cursor.fetchall()
    
    print(f"Found {len(leaders)} leaders. Fetching real photos from Wikipedia API...")
    
    updated_count = 0
    for idx, (l_id, name) in enumerate(leaders):
        photo = get_wiki_image(name)
        if photo:
            cursor.execute("UPDATE public.leaders_master SET photo_url = %s WHERE id = %s", (photo, l_id))
            updated_count += 1
            if idx % 50 == 0:
                print(f"Processed {idx}/{len(leaders)}... Found {updated_count} photos so far.")
        time.sleep(0.1) # Be nice to Wikipedia API
            
    print(f"Successfully updated {updated_count} leaders with REAL photos!")
    cursor.close()
    conn.close()

except Exception as e:
    print(f"Error: {e}")
    sys.exit(1)

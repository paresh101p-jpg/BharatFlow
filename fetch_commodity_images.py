import os
import time
import requests
from io import BytesIO
from PIL import Image
from supabase import create_client, Client

SUPABASE_URL = "https://wkhelvyqudzyzbrayyqo.supabase.co/"
SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndraGVsdnlxdWR6eXpicmF5eXFvIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NzY2ODE5NCwiZXhwIjoyMDkzMjQ0MTk0fQ.4wM9t8CBYkpP8fkGxT0yyljQMOpn9o5RbC5_foEq-K0"

supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)
bucket_name = "commodity_images"

from duckduckgo_search import DDGS

def get_duckduckgo_image(query):
    try:
        with DDGS() as ddgs:
            # Adding "crop vegetable agriculture india" to improve context
            search_query = f"{query} crop OR vegetable OR agriculture India high quality"
            results = list(ddgs.images(search_query, max_results=1, type_image="photo"))
            if results:
                return results[0]["image"]
    except Exception as e:
        print("DuckDuckGo API Error:", e)
    return None

def setup_bucket():
    try:
        buckets = supabase.storage.list_buckets()
        bucket_exists = any(b.name == bucket_name for b in buckets)
        if not bucket_exists:
            supabase.storage.create_bucket(bucket_name, options={"public": True})
    except Exception as e:
        print("Bucket check error:", e)

def compress_image(image_bytes):
    try:
        img = Image.open(BytesIO(image_bytes))
        if img.mode in ("RGBA", "P"):
            img = img.convert("RGB")
        img.thumbnail((300, 300))
        output = BytesIO()
        img.save(output, format="JPEG", quality=60, optimize=True)
        return output.getvalue()
    except Exception as e:
        print("Compression error:", e)
        return None

def fetch_and_upload():
    setup_bucket()
    
    import random
    import time

    # Fetch missing images (limit to 20 for safety to avoid rate limits)
    response = supabase.table("commodity_images").select("commodity_name, image_url").execute()
    commodities = [row["commodity_name"] for row in response.data if not row.get("image_url")][:20]
    
    print(f"Found {len(commodities)} commodities without images. Starting process...")
    
    for idx, name in enumerate(commodities):
        safe_name = "".join(c if c.isalnum() else "_" for c in name).strip("_")
        file_name = f"{safe_name}.jpg"
        
        print(f"[{idx+1}/{len(commodities)}] Processing: {name}")
        
        # Add random delay before request (10 to 20 seconds) to bypass bot detection
        delay = random.randint(10, 20)
        print(f"  Sleeping {delay}s to avoid rate limit...")
        time.sleep(delay)
        
        image_url = get_duckduckgo_image(name)
        
        if not image_url:
            print(f"  No image found on DuckDuckGo for {name}")
            # Mark it with a generic avatar so we don't keep retrying and getting stuck
            avatar_url = f"https://ui-avatars.com/api/?name={name.replace(' ', '+')}&background=1B5E20&color=fff&size=200"
            supabase.table("commodity_images").update({"image_url": avatar_url}).eq("commodity_name", name).execute()
            continue
            
        try:
            # Download
            headers = {"User-Agent": "BharatFlowApp/1.0"}
            img_res = requests.get(image_url, headers=headers, timeout=10)
            if img_res.status_code == 200:
                compressed_bytes = compress_image(img_res.content)
                if not compressed_bytes:
                    continue
                    
                print(f"  Compressed size: {len(compressed_bytes)//1024} KB. Uploading...")
                
                try:
                    supabase.storage.from_(bucket_name).remove([file_name])
                except:
                    pass
                    
                supabase.storage.from_(bucket_name).upload(
                    file_name,
                    compressed_bytes,
                    file_options={"content-type": "image/jpeg"}
                )
                
                public_url = supabase.storage.from_(bucket_name).get_public_url(file_name)
                supabase.table("commodity_images").update({"image_url": public_url}).eq("commodity_name", name).execute()
                print("  Success!")
            else:
                print(f"  Failed to download. Status: {img_res.status_code}")
                
        except Exception as e:
            print(f"  Error for {name}: {str(e)[:100]}")
            
        time.sleep(2)

if __name__ == "__main__":
    fetch_and_upload()
    print("ALL DONE")

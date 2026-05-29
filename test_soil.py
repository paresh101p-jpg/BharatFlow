import requests

def test_api():
    lat = 23.0
    lon = 72.0
    api_url = (f"https://api.open-meteo.com/v1/forecast?latitude={lat}&longitude={lon}"
               f"&current=soil_moisture_0_to_1cm&timezone=auto")
    try:
        res = requests.get(api_url).json()
        print("Response:", res)
        # Convert m3/m3 to percentage (0.0 to 1.0)
        moisture = res['current']['soil_moisture_0_to_1cm'] * 100
        print("Moisture:", int(moisture))
    except Exception as e:
        print("Error:", e)

if __name__ == "__main__":
    test_api()

import requests
import json
from datetime import datetime, timedelta

CLIENT_ID = "sh-2525500a-b3c6-403e-a709-6bf69fce565e"
CLIENT_SECRET = "l90e96a4lDjSlQrQ94h7qZMUrGrn3ZSC"

def get_token():
    url = "https://identity.dataspace.copernicus.eu/auth/realms/CDSE/protocol/openid-connect/token"
    payload = {
        "client_id": CLIENT_ID,
        "client_secret": CLIENT_SECRET,
        "grant_type": "client_credentials"
    }
    response = requests.post(url, data=payload)
    if response.status_code == 200:
        return response.json().get("access_token")
    else:
        raise Exception(f"Failed to get token: {response.text}")

def test_stats():
    token = get_token()
    print("Token fetched!")
    
    url = "https://sh.dataspace.copernicus.eu/api/v1/statistics"
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    }
    
    end_date = datetime.utcnow()
    start_date = end_date - timedelta(days=30)
    
    time_from = start_date.strftime("%Y-%m-%dT00:00:00Z")
    time_to = end_date.strftime("%Y-%m-%dT23:59:59Z")
    
    # A small polygon in Gujarat
    polygon = [
        [72.0, 23.0],
        [72.01, 23.0],
        [72.01, 23.01],
        [72.0, 23.01],
        [72.0, 23.0]
    ]
    
    evalscript = """//VERSION=3
function setup() {
  return {
    input: ["B08", "B11", "dataMask"],
    output: [
      { id: "default", bands: 1, sampleType: "FLOAT32" },
      { id: "dataMask", bands: 1, sampleType: "UINT8" }
    ]
  };
}
function evaluatePixel(sample) {
  let ndmi = (sample.B08 - sample.B11) / (sample.B08 + sample.B11);
  return {
    default: [ndmi],
    dataMask: [sample.dataMask]
  };
}"""

    payload = {
        "input": {
            "bounds": {
                "geometry": {
                    "type": "Polygon",
                    "coordinates": [polygon]
                }
            },
            "data": [
                {
                    "dataFilter": {
                        "timeRange": {
                            "from": time_from,
                            "to": time_to
                        }
                    },
                    "type": "sentinel-2-l2a"
                }
            ]
        },
        "aggregation": {
            "timeRange": {
                "from": time_from,
                "to": time_to
            },
            "aggregationInterval": {
                "of": "P30D"
            },
            "evalscript": evalscript
        }
    }
    
    res = requests.post(url, headers=headers, json=payload)
    print("Status Code:", res.status_code)
    try:
        data = res.json()
        print(json.dumps(data, indent=2))
        
        # Extract mean
        if "data" in data and len(data["data"]) > 0:
            outputs = data["data"][0].get("outputs", {})
            if "default" in outputs:
                bands = outputs["default"].get("bands", {})
                if "B0" in bands:
                    mean_ndmi = bands["B0"][1] # index 1 is mean
                    print("Mean NDMI:", mean_ndmi)
                    # NDMI ranges from -1 to +1.
                    # Convert to percentage 0 to 100
                    if mean_ndmi is not None:
                        moisture_percentage = int(((mean_ndmi + 1) / 2) * 100)
                        print("Calculated Moisture %:", moisture_percentage)
    except Exception as e:
        print("Error parsing:", e)

if __name__ == "__main__":
    test_stats()

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import requests
import json
import datetime

app = FastAPI(title="BharatFlow Real CDSE API")

CLIENT_ID = "sh-2525500a-b3c6-403e-a709-6bf69fce565e"
CLIENT_SECRET = "l90e96a4lDjSlQrQ94h7qZMUrGrn3ZSC"

class PolygonRequest(BaseModel):
    crop_id: str
    points: list[dict] # e.g. [{"lat": 23.4, "lng": 72.3}, ...]

def get_cdse_token():
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

@app.post("/scan-soil-moisture")
def scan_soil_moisture(req: PolygonRequest):
    if len(req.points) < 3:
        raise HTTPException(status_code=400, detail="Polygon must have at least 3 points")

    try:
        token = get_cdse_token()
        
        # Format polygon (close it)
        coords = [[p['lng'], p['lat']] for p in req.points]
        coords.append(coords[0])
        
        end_date = datetime.datetime.utcnow()
        start_date = end_date - datetime.timedelta(days=30)
        time_from = start_date.strftime("%Y-%m-%dT00:00:00Z")
        time_to = end_date.strftime("%Y-%m-%dT23:59:59Z")
        
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
                        "coordinates": [coords]
                    }
                },
                "data": [
                    {
                        "dataFilter": {"timeRange": {"from": time_from, "to": time_to}},
                        "type": "sentinel-2-l2a"
                    }
                ]
            },
            "aggregation": {
                "timeRange": {"from": time_from, "to": time_to},
                "aggregationInterval": {"of": "P30D"},
                "evalscript": evalscript
            }
        }
        
        url = "https://sh.dataspace.copernicus.eu/api/v1/statistics"
        headers = {"Authorization": f"Bearer {token}", "Content-Type": "application/json"}
        
        res = requests.post(url, headers=headers, json=payload)
        
        if res.status_code != 200:
            raise Exception(f"CDSE API Error: {res.text}")
            
        data = res.json()
        mean_ndmi = None
        if "data" in data and len(data["data"]) > 0:
            outputs = data["data"][0].get("outputs", {})
            if "default" in outputs:
                bands = outputs["default"].get("bands", {})
                if "B0" in bands and "stats" in bands["B0"]:
                    mean_ndmi = bands["B0"]["stats"].get("mean")
                    
        if mean_ndmi is not None:
            # NDMI ranges from -1 to 1. Convert to 0-100 percentage
            moisture_percentage = int(((mean_ndmi + 1) / 2) * 100)
            return {
                "status": "success",
                "soil_moisture_percentage": moisture_percentage,
                "satellite": "Copernicus Sentinel-2 (Live)",
                "message": "Real data processed successfully via CDSE"
            }
        else:
            raise Exception("No valid moisture data found for this location")
            
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)

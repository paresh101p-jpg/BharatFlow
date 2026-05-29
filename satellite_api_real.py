from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import requests
import json

app = FastAPI(title="BharatFlow Real Satellite Soil Moisture API")

class PolygonRequest(BaseModel):
    crop_id: str
    points: list[dict] # e.g. [{"lat": 23.4, "lng": 72.3}, ...]

@app.post("/scan-soil-moisture")
def scan_soil_moisture(req: PolygonRequest):
    if not req.points:
        raise HTTPException(status_code=400, detail="Must provide at least 1 point")

    try:
        lat = req.points[0]['lat']
        lon = req.points[0]['lng']
        
        # We use Open-Meteo API to fetch REAL soil moisture for the coordinates!
        api_url = (f"https://api.open-meteo.com/v1/forecast?latitude={lat}&longitude={lon}"
                   f"&current=soil_moisture_0_to_1cm&timezone=auto")
        
        res = requests.get(api_url).json()
        
        if 'current' in res and 'soil_moisture_0_to_1cm' in res['current']:
            # The value is in m3/m3 (e.g. 0.40). Convert to percentage.
            moisture_val = res['current']['soil_moisture_0_to_1cm']
            moisture_percentage = int(moisture_val * 100)
            
            return {
                "status": "success",
                "soil_moisture_percentage": moisture_percentage,
                "satellite": "Open-Meteo Model Data",
                "message": "Real data processed successfully"
            }
        else:
            raise Exception("No moisture data available for this location")
            
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    import uvicorn
    # Runs on port 8000
    uvicorn.run(app, host="0.0.0.0", port=8000)

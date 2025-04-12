from fastapi import FastAPI, Request
from fastapi.responses import FileResponse
import logging, requests, json

app = FastAPI()
LOGO_PATH = "logo-itanderbar.png"

def geoip_lookup(ip):
    try:
        return requests.get(f"http://ip-api.com/json/{ip}").json()
    except: return {"error": "GeoIP failed"}

@app.get("/")
async def root(request: Request):
    headers = dict(request.headers)
    ip = request.client.host
    geo = geoip_lookup(ip)
    log_data = {
        "ip": ip,
        "geo": geo,
        "ua": headers.get("user-agent"),
        "headers": headers
    }
    logging.warning(json.dumps(log_data, indent=2))
    return FileResponse(LOGO_PATH, media_type="image/png")

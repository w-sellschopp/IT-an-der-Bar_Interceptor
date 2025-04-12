from fastapi import FastAPI, Request
from fastapi.responses import FileResponse
import logging
import requests
import json
import socket
import sys

# Logging nach stdout (für Kubernetes Logs)
logging.basicConfig(stream=sys.stdout, level=logging.INFO)

app = FastAPI()

LOGO_PATH = "logo-itanderbar.png"

def geoip_lookup(ip):
    try:
        response = requests.get(f"http://ip-api.com/json/{ip}")
        return response.json()
    except Exception as e:
        return {"error": str(e)}

def reverse_dns_lookup(ip):
    try:
        return socket.gethostbyaddr(ip)[0]
    except Exception:
        return "n/a"

@app.get("/")
async def track_image(request: Request):
    headers = dict(request.headers)

    # Echte Client-IP über X-Real-IP oder X-Forwarded-For
    ip = headers.get("x-real-ip") or headers.get("x-forwarded-for", "").split(",")[0].strip()
    if not ip:
        ip = request.client.host  # Fallback

    geo = geoip_lookup(ip)
    reverse_dns = reverse_dns_lookup(ip)

    log_data = {
        "client_ip": ip,
        "reverse_dns": reverse_dns,
        "geoip": geo,
        "user_agent": headers.get("user-agent"),
        "accept": headers.get("accept"),
        "referrer": headers.get("referer"),
        "headers": headers
    }

    logging.info(json.dumps(log_data, indent=2))

    return FileResponse(LOGO_PATH, media_type="image/png")

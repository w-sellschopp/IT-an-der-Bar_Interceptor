from fastapi import FastAPI, Request
from fastapi.responses import FileResponse
import logging
import requests
import json
import socket
import sys
from datetime import datetime
from user_agents import parse as parse_ua

# Logging nach stdout (für Kubernetes Logs)
logging.basicConfig(stream=sys.stdout, level=logging.INFO)

app = FastAPI()
LOGO_PATH = "logo-itanderbar.png"

def geoip_lookup(ip):
    try:
        response = requests.get(f"http://ip-api.com/json/{ip}?fields=status,message,continent,continentCode,country,countryCode,regionName,city,zip,lat,lon,timezone,isp,org,as,asname,reverse,query")
        return response.json()
    except Exception as e:
        return {"error": str(e)}

def reverse_dns_lookup(ip):
    try:
        return socket.gethostbyaddr(ip)[0]
    except Exception:
        return "n/a"

def pretty_print(data: dict):
    print("\n" + "=" * 60)
    print("📦 Neue Bildanfrage erhalten:")
    print("=" * 60)
    print(f"🕒 Zeit (UTC):          {data['timestamp_utc']}")
    print(f"🌍 IP-Adresse:         {data['client_ip']}")
    print(f"🔎 Reverse DNS:        {data['reverse_dns']}")
    
    geo = data['geoip']
    if geo.get("status") == "success":
        print(f"📌 Ort:                {geo.get('city')}, {geo.get('regionName')} {geo.get('zip')}")
        print(f"🌐 Land:               {geo.get('country')} ({geo.get('countryCode')})")
        print(f"🛰️ ISP / ASN:          {geo.get('isp')} / {geo.get('as')}")
        print(f"🕓 Zeitzone:           {geo.get('timezone')}")
        print(f"📍 Koordinaten:        {geo.get('lat')}, {geo.get('lon')}")
    else:
        print("⚠️ GeoIP nicht verfügbar")

    ua = data['user_agent']
    print("\n🖥️ Gerät & Browser:")
    print(f"   - Gerät:            {ua['device']}")
    print(f"   - OS:               {ua['os']}")
    print(f"   - Browser:          {ua['browser']}")
    print(f"   - Mobil:            {ua['is_mobile']}, Tablet: {ua['is_tablet']}, PC: {ua['is_pc']}, Bot: {ua['is_bot']}")

    print("\n📨 HTTP-Header (Auszug):")
    headers = data['headers']
    print(f"   - Referrer:         {headers.get('referer')}")
    print(f"   - Sprache:          {headers.get('accept_language')}")
    print(f"   - Accept:           {headers.get('accept')}")
    print(f"   - Host:             {headers.get('host')}")
    print(f"   - DNT (Tracking):   {headers.get('dnt')}")
    print(f"   - Via:              {headers.get('via')}")
    print(f"   - X-Forwarded-For:  {headers.get('x_forwarded_for')}")
    print(f"   - X-Real-IP:        {headers.get('x_real_ip')}")

    print(f"\n🔖 Tracking-ID:        {data.get('track_id')}")
    print("=" * 60 + "\n")

# Tracking-Endpunkt (zentrale Logik)
async def handle_tracking(request: Request):
    headers = dict(request.headers)
    query_params = dict(request.query_params)

    ip = headers.get("x-real-ip") or headers.get("x-forwarded-for", "").split(",")[0].strip()
    if not ip:
        ip = request.client.host

    geo = geoip_lookup(ip)
    reverse_dns = reverse_dns_lookup(ip)
    timestamp = datetime.utcnow().isoformat() + "Z"

    ua_raw = headers.get("user-agent", "")
    ua = parse_ua(ua_raw)
    user_agent_details = {
        "browser": f"{ua.browser.family} {ua.browser.version_string}",
        "os": f"{ua.os.family} {ua.os.version_string}",
        "device": ua.device.family,
        "is_mobile": ua.is_mobile,
        "is_tablet": ua.is_tablet,
        "is_pc": ua.is_pc,
        "is_bot": ua.is_bot
    }

    track_id = query_params.get("track")

    log_data = {
        "timestamp_utc": timestamp,
        "client_ip": ip,
        "reverse_dns": reverse_dns,
        "geoip": geo,
        "user_agent": user_agent_details,
        "raw_user_agent": ua_raw,
        "headers": {
            "accept": headers.get("accept"),
            "accept_language": headers.get("accept-language"),
            "referer": headers.get("referer"),
            "host": headers.get("host"),
            "connection": headers.get("connection"),
            "dnt": headers.get("dnt"),
            "via": headers.get("via"),
            "forwarded": headers.get("forwarded"),
            "x_forwarded_for": headers.get("x-forwarded-for"),
            "x_real_ip": headers.get("x-real-ip")
        },
        "track_id": track_id
    }

    logging.info(json.dumps(log_data))
    pretty_print(log_data)

    return FileResponse(LOGO_PATH, media_type="image/png")

# Endpunkte
@app.get("/")
async def root(request: Request):
    return await handle_tracking(request)

@app.get("/logo.png")
async def logo(request: Request):
    return await handle_tracking(request)

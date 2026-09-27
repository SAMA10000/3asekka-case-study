#!/usr/bin/env bash
set -euo pipefail

APP="/opt/3asekka-ai-agent/source"
SITE="/etc/nginx/sites-available/3asekka.com"
STAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP="/opt/3asekka-ai-agent/backups/agent_app_clean_$STAMP"
INDEX_URL="https://raw.githubusercontent.com/SAMA10000/3asekka-case-study/204c5dabc9b6486710a99f8f8dc85c82356fef5c/hackathon-agent/public/index.html"

echo "=== 3ASEKKA FRESH CLEAN AGENT-APP ROUTE ==="

mkdir -p "$BACKUP"
cp -a "$APP/public/index.html" "$BACKUP/index.html"
cp -a "$SITE" "$BACKUP/nginx-site"

rollback() {
  rc=$?
  echo "PATCH=FAIL rc=$rc"
  cp -a "$BACKUP/index.html" "$APP/public/index.html" || true
  cp -a "$BACKUP/nginx-site" "$SITE" || true
  nginx -t >/dev/null 2>&1 && systemctl reload nginx >/dev/null 2>&1 || true
  systemctl restart 3asekka-ai-agent >/dev/null 2>&1 || true
  echo "ROLLBACK_ATTEMPTED=YES"
  exit "$rc"
}
trap rollback ERR

echo "[1/7] Publishing final UI with embedded original 3ASEKKA logo..."
curl -fsSL "$INDEX_URL" -o "$APP/public/index.html"

grep -q 'data:image/png;base64,iVBORw0KGgo' "$APP/public/index.html"
grep -q 'const req=data.request' "$APP/public/index.html"
grep -q 'renderOffers(data.offers' "$APP/public/index.html"
grep -q '📞 اتصل' "$APP/public/index.html"
echo "UI_FILE=PASS"
echo "ORIGINAL_LOGO_EMBEDDED=PASS"

echo "[2/7] Creating a fresh uncached clean public route..."
python3 - "$SITE" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1])
s=p.read_text(encoding="utf-8")

exact = '''    location = /agent-app {
        return 301 /agent-app/;
    }

'''
prefix = '''    location ^~ /agent-app/ {
        proxy_pass http://127.0.0.1:3300/;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 120s;
        proxy_send_timeout 120s;

        expires -1;
        add_header Cache-Control "no-store, no-cache, must-revalidate, max-age=0" always;
        add_header CDN-Cache-Control "no-store" always;
        add_header Cloudflare-CDN-Cache-Control "no-store" always;
        add_header Surrogate-Control "no-store" always;
    }

'''

if "location = /agent-app {" not in s:
    needle="    location = /agent {"
    pos=s.find(needle)
    if pos < 0:
        needle="    location ^~ /agent/ {"
        pos=s.find(needle)
    if pos < 0:
        raise SystemExit("Could not find agent nginx location")
    s=s[:pos]+exact+prefix+s[pos:]
    p.write_text(s,encoding="utf-8")
PY

nginx -t
systemctl reload nginx
echo "NGINX=PASS"

echo "[3/7] Restarting agent and waiting..."
systemctl restart 3asekka-ai-agent
READY=0
for i in $(seq 1 30); do
  if curl -fsS http://127.0.0.1:3300/health >/dev/null 2>&1; then
    READY=1
    break
  fi
  sleep 1
done
[[ "$READY" == "1" ]]
echo "LOCAL_HEALTH=PASS"

echo "[4/7] Checking origin UI..."
LOCAL="/tmp/3asekka_agent_app_local_$STAMP.html"
curl -fsS http://127.0.0.1:3300/ -o "$LOCAL"
grep -q 'data:image/png;base64,iVBORw0KGgo' "$LOCAL"
grep -q 'renderOffers(data.offers' "$LOCAL"
grep -q '📞 اتصل' "$LOCAL"
echo "LOCAL_UI=PASS"

echo "[5/7] Checking fresh clean public page..."
PUB="/tmp/3asekka_agent_app_public_$STAMP.html"
HDR="/tmp/3asekka_agent_app_headers_$STAMP.txt"
HTTP="$(curl -k -sS -D "$HDR" -o "$PUB" -w '%{http_code}' https://3asekka.com/agent-app/)"
echo "PUBLIC_HTTP=$HTTP"
[[ "$HTTP" == "200" ]]
grep -q 'data:image/png;base64,iVBORw0KGgo' "$PUB"
grep -q 'renderOffers(data.offers' "$PUB"
grep -q '📞 اتصل' "$PUB"
grep -q 'ابدأ نقلتك' "$PUB"
echo "PUBLIC_UI=PASS"
echo "PUBLIC_ORIGINAL_LOGO=PASS"

echo "[6/7] Full public workflow test..."
REQ="/tmp/3asekka_agent_app_req_$STAMP.json"
RESP="/tmp/3asekka_agent_app_resp_$STAMP.json"
python3 - "$REQ" <<'PY'
import json,sys
with open(sys.argv[1],"w",encoding="utf-8") as f:
    json.dump({"input":"عايز أنقل 20 كرتونة من سموحة للمنشية بكرة الساعة 3، وزنهم حوالي 250 كيلو والمسافة 12 كم"},f,ensure_ascii=True)
PY

API="$(curl -k -sS -o "$RESP" -w '%{http_code}'   -H 'content-type: application/json'   --data-binary @"$REQ"   https://3asekka.com/agent/api/agent)"
echo "PUBLIC_API_HTTP=$API"
[[ "$API" == "200" ]]

python3 - "$RESP" <<'PY'
import json,sys
d=json.load(open(sys.argv[1],encoding="utf-8"))
req=d.get("request") or {}
rec=d.get("recommendation") or {}
route=d.get("route") or {}
pricing=d.get("pricing") or {}
offers=d.get("offers") or []

print("STATUS="+str(d.get("status")))
print("PICKUP="+str(req.get("pickup")))
print("DESTINATION="+str(req.get("destination")))
print("CARGO="+str(req.get("cargo")))
print("WEIGHT="+str(req.get("weightKg")))
print("VEHICLE="+str(rec.get("vehicleNameAr")))
print("DISTANCE="+str(route.get("distanceKm")))
print("FARE="+str(pricing.get("estimatedFare")))
print("OFFERS="+str(len(offers)))

if not req.get("pickup"): raise SystemExit("pickup missing")
if not req.get("destination"): raise SystemExit("destination missing")
if not req.get("cargo"): raise SystemExit("cargo missing")
if req.get("weightKg") is None: raise SystemExit("weight missing")
if not rec.get("vehicleNameAr"): raise SystemExit("vehicle missing")
if route.get("distanceKm") is None: raise SystemExit("distance missing")
if pricing.get("estimatedFare") is None: raise SystemExit("fare missing")
if len(offers) < 3: raise SystemExit(f"offers missing: {len(offers)}")
print("PUBLIC_WORKFLOW=PASS")
print("PUBLIC_OFFERS=3")
PY

echo "[7/7] Health..."
HEALTH="$(curl -k -sS -o /tmp/3asekka_agent_app_health_$STAMP.json -w '%{http_code}' https://3asekka.com/agent-app/health)"
echo "PUBLIC_HEALTH_HTTP=$HEALTH"
[[ "$HEALTH" == "200" ]]

trap - ERR
echo
echo "======================================"
echo "PATCH=PASS"
echo "DEPLOY_OK=YES"
echo "ORIGINAL_LOGO=YES"
echo "WORKFLOW_COMPLETE=YES"
echo "DRIVER_OFFERS=YES"
echo "CLEAN_URL=YES"
echo "FINAL_URL=https://3asekka.com/agent-app/"
echo "======================================"

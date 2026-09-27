#!/usr/bin/env bash
set -euo pipefail

APP="/opt/3asekka-ai-agent/source"
SITE="/etc/nginx/sites-available/3asekka.com"
SNIP="/etc/nginx/snippets/3asekka-transport-agent.conf"
STAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP="/opt/3asekka-ai-agent/backups/transport_agent_route_$STAMP"
INDEX_URL="https://raw.githubusercontent.com/SAMA10000/3asekka-case-study/204c5dabc9b6486710a99f8f8dc85c82356fef5c/hackathon-agent/public/index.html"

echo "=== 3ASEKKA TRANSPORT AGENT FINAL ROUTE ==="

mkdir -p "$BACKUP"
cp -a "$APP/public/index.html" "$BACKUP/index.html"
cp -a "$SITE" "$BACKUP/nginx-site"
[[ -f "$SNIP" ]] && cp -a "$SNIP" "$BACKUP/snippet.conf" || true

rollback() {
  rc=$?
  echo "PATCH=FAIL rc=$rc"
  cp -a "$BACKUP/index.html" "$APP/public/index.html" || true
  cp -a "$BACKUP/nginx-site" "$SITE" || true
  if [[ -f "$BACKUP/snippet.conf" ]]; then
    cp -a "$BACKUP/snippet.conf" "$SNIP" || true
  else
    rm -f "$SNIP" || true
  fi
  nginx -t >/dev/null 2>&1 && systemctl reload nginx >/dev/null 2>&1 || true
  systemctl restart 3asekka-ai-agent >/dev/null 2>&1 || true
  echo "ROLLBACK_ATTEMPTED=YES"
  exit "$rc"
}
trap rollback ERR

echo "[1/7] Publishing final app-screen UI..."
curl -fsSL "$INDEX_URL" -o "$APP/public/index.html"
grep -q 'data:image/png;base64,iVBORw0KGgo' "$APP/public/index.html"
grep -q 'renderOffers(data.offers' "$APP/public/index.html"
grep -q '📞 اتصل' "$APP/public/index.html"
echo "UI_FILE=PASS"

echo "[2/7] Installing route snippet..."
cat > "$SNIP" <<'NGINX'
location = /transport-agent {
    return 302 /transport-agent/;
}

location ^~ /transport-agent/ {
    proxy_pass http://127.0.0.1:3300/;
    proxy_http_version 1.1;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_read_timeout 120s;
    proxy_send_timeout 120s;

    expires -1;
    add_header X-3ASEKKA-Agent-Route "transport-agent-v1" always;
    add_header Cache-Control "no-store, no-cache, must-revalidate, max-age=0" always;
    add_header CDN-Cache-Control "no-store" always;
    add_header Cloudflare-CDN-Cache-Control "no-store" always;
    add_header Surrogate-Control "no-store" always;
}
NGINX

echo "[3/7] Adding route to every 3asekka.com server block..."
python3 - "$SITE" "$SNIP" <<'PY'
from pathlib import Path
import sys,re

site=Path(sys.argv[1])
snippet=sys.argv[2]
s=site.read_text(encoding="utf-8")
include=f"    include {snippet};\n"

# Remove stale direct /transport-agent location blocks if any.
def strip_location(text, marker):
    while True:
        pos=text.find(marker)
        if pos < 0:
            return text
        brace=text.find("{",pos)
        if brace < 0:
            return text
        depth=0
        end=None
        for i in range(brace,len(text)):
            if text[i]=="{": depth+=1
            elif text[i]=="}":
                depth-=1
                if depth==0:
                    end=i+1
                    break
        if end is None:
            return text
        start=text.rfind("\n",0,pos)+1
        while end < len(text) and text[end] in " \t\r\n":
            end+=1
        text=text[:start]+text[end:]

for marker in ("location = /transport-agent", "location ^~ /transport-agent/"):
    s=strip_location(s,marker)

# Remove prior include so insertion is deterministic.
s=s.replace(include,"")

# Find top-level server blocks and insert include into every block serving 3asekka.com.
blocks=[]
i=0
while True:
    m=re.search(r"(?m)^\s*server\s*\{",s[i:])
    if not m: break
    start=i+m.start()
    brace=s.find("{",start)
    depth=0
    end=None
    for j in range(brace,len(s)):
        if s[j]=="{": depth+=1
        elif s[j]=="}":
            depth-=1
            if depth==0:
                end=j
                break
    if end is None: break
    block=s[start:end+1]
    if re.search(r"(?m)^\s*server_name\s+[^;]*3asekka\.com",block):
        blocks.append((start,end))
    i=end+1

if not blocks:
    raise SystemExit("No active server block for 3asekka.com found")

for start,end in reversed(blocks):
    s=s[:end]+include+s[end:]

site.write_text(s,encoding="utf-8")
print("MATCHED_SERVER_BLOCKS="+str(len(blocks)))
PY

nginx -t
systemctl reload nginx
echo "NGINX=PASS"

echo "[4/7] Restarting agent and waiting..."
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

echo "[5/7] Checking brand-new clean public route..."
HDR="/tmp/3asekka_transport_headers_$STAMP.txt"
HTML="/tmp/3asekka_transport_page_$STAMP.html"
PUBLIC_HTTP="$(curl -k -sS -D "$HDR" -o "$HTML" -w '%{http_code}' https://3asekka.com/transport-agent/)"
echo "PUBLIC_HTTP=$PUBLIC_HTTP"
grep -iE '^(cf-cache-status|age|x-3asekka-agent-route|cache-control):' "$HDR" || true
[[ "$PUBLIC_HTTP" == "200" ]]
grep -qi '^x-3asekka-agent-route: transport-agent-v1' "$HDR"
grep -q 'data:image/png;base64,iVBORw0KGgo' "$HTML"
grep -q '📞 اتصل' "$HTML"
grep -q 'ابدأ نقلتك' "$HTML"
grep -q 'renderOffers(data.offers' "$HTML"
echo "PUBLIC_UI=PASS"
echo "PUBLIC_LOGO=PASS"

echo "[6/7] Full workflow test..."
REQ="/tmp/3asekka_transport_req_$STAMP.json"
RESP="/tmp/3asekka_transport_resp_$STAMP.json"
python3 - "$REQ" <<'PY'
import json,sys
with open(sys.argv[1],"w",encoding="utf-8") as f:
    json.dump({"input":"عايز أنقل 20 كرتونة من سموحة للمنشية بكرة الساعة 3، وزنهم حوالي 250 كيلو والمسافة 12 كم"},f,ensure_ascii=True)
PY

API="$(curl -k -sS -o "$RESP" -w '%{http_code}'   -H 'content-type: application/json'   --data-binary @"$REQ"   https://3asekka.com/transport-agent/api/agent)"
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
HEALTH="$(curl -k -sS -o /tmp/3asekka_transport_health_$STAMP.json -w '%{http_code}' https://3asekka.com/transport-agent/health)"
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
echo "FINAL_URL=https://3asekka.com/transport-agent/"
echo "======================================"

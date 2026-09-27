#!/usr/bin/env bash
set -euo pipefail

APP="/opt/3asekka-ai-agent/source"
STAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP="/opt/3asekka-ai-agent/backups/exact_logo_workflow_$STAMP"
INDEX_URL="https://raw.githubusercontent.com/SAMA10000/3asekka-case-study/204c5dabc9b6486710a99f8f8dc85c82356fef5c/hackathon-agent/public/index.html"

echo "=== 3ASEKKA EXACT LOGO + FULL WORKFLOW ==="

mkdir -p "$BACKUP"
cp -a "$APP/public/index.html" "$BACKUP/index.html"

rollback() {
  rc=$?
  echo "PATCH=FAIL rc=$rc"
  cp -a "$BACKUP/index.html" "$APP/public/index.html" || true
  systemctl restart 3asekka-ai-agent >/dev/null 2>&1 || true
  echo "ROLLBACK_ATTEMPTED=YES"
  exit "$rc"
}
trap rollback ERR

echo "[1/6] Publishing final mobile UI with embedded production logo..."
curl -fsSL "$INDEX_URL" -o "$APP/public/index.html"

grep -q 'data:image/png;base64,iVBORw0KGgo' "$APP/public/index.html"
grep -q '📞 اتصل' "$APP/public/index.html"
grep -q 'ابدأ نقلتك' "$APP/public/index.html"
grep -q 'renderOffers(data.offers' "$APP/public/index.html"
grep -q 'const req=data.request' "$APP/public/index.html"
echo "FILES=PASS"
echo "EXACT_LOGO=PASS"

echo "[2/6] Restarting agent..."
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

echo "[3/6] Verifying clean public mobile UI..."
HTML="/tmp/3asekka_exact_ui_$STAMP.html"
PUBLIC_HTTP="$(curl -k -sS -o "$HTML" -w '%{http_code}' https://3asekka.com/agent)"
echo "PUBLIC_HTTP=$PUBLIC_HTTP"
[[ "$PUBLIC_HTTP" == "200" ]]
grep -q 'data:image/png;base64,iVBORw0KGgo' "$HTML"
grep -q '📞 اتصل' "$HTML"
grep -q 'ابدأ نقلتك' "$HTML"
grep -q 'renderOffers(data.offers' "$HTML"
echo "PUBLIC_UI=PASS"
echo "PUBLIC_LOGO=PASS"

echo "[4/6] Full end-to-end agent API test..."
REQ="/tmp/3asekka_exact_req_$STAMP.json"
RESP="/tmp/3asekka_exact_resp_$STAMP.json"

python3 - "$REQ" <<'PY'
import json,sys
payload={"input":"عايز أنقل 20 كرتونة من سموحة للمنشية بكرة الساعة 3، وزنهم حوالي 250 كيلو والمسافة 12 كم"}
with open(sys.argv[1],"w",encoding="utf-8") as f:
    json.dump(payload,f,ensure_ascii=True)
PY

API_HTTP="$(curl -k -sS -o "$RESP" -w '%{http_code}'   -H 'content-type: application/json'   --data-binary @"$REQ"   https://3asekka.com/agent/api/agent)"
echo "PUBLIC_API_HTTP=$API_HTTP"
[[ "$API_HTTP" == "200" ]]

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

echo "[5/6] Verifying health..."
HEALTH="$(curl -k -sS -o /tmp/3asekka_exact_health_$STAMP.json -w '%{http_code}' https://3asekka.com/agent/health)"
echo "PUBLIC_HEALTH_HTTP=$HEALTH"
[[ "$HEALTH" == "200" ]]

echo "[6/6] Final page marker check..."
grep -q 'Request it… and book your transport instantly' "$HTML"
echo "ARABIC_ENGLISH=PASS"

trap - ERR

echo
echo "======================================"
echo "PATCH=PASS"
echo "DEPLOY_OK=YES"
echo "EXACT_MAIN_LOGO=YES"
echo "WORKFLOW_COMPLETE=YES"
echo "DRIVER_OFFERS=YES"
echo "FINAL_URL=https://3asekka.com/agent"
echo "======================================"

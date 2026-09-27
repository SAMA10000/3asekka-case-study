#!/usr/bin/env bash
set -euo pipefail

APP="/opt/3asekka-ai-agent/source"
STAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP="/opt/3asekka-ai-agent/backups/final_mobile_workflow_$STAMP"
INDEX_URL="https://raw.githubusercontent.com/SAMA10000/3asekka-case-study/29861d3c045456ef48200da19703a48afa34b3e3/hackathon-agent/public/index.html"

echo "=== 3ASEKKA FINAL MOBILE WORKFLOW PATCH ==="

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

echo "[1/6] Publishing final mobile UI..."
curl -fsSL "$INDEX_URL" -o "$APP/public/index.html"
grep -q '/assets/images/logo_icon/logo.png' "$APP/public/index.html"
grep -q 'data.request' "$APP/public/index.html"
grep -q 'data.recommendation' "$APP/public/index.html"
grep -q 'data.pricing' "$APP/public/index.html"
grep -q 'data.offers' "$APP/public/index.html"
echo "FILES=PASS"

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

echo "[3/6] Checking production logo asset..."
LOGO_HTTP="$(curl -k -sS -o /tmp/3asekka_logo_$STAMP.png -w '%{http_code}' https://3asekka.com/assets/images/logo_icon/logo.png)"
echo "LOGO_HTTP=$LOGO_HTTP"
[[ "$LOGO_HTTP" == "200" ]]
echo "LOGO_ASSET=PASS"

echo "[4/6] Checking public mobile UI..."
HTML="/tmp/3asekka_final_mobile_$STAMP.html"
HTTP="$(curl -k -sS -o "$HTML" -w '%{http_code}' https://3asekka.com/agent)"
echo "PUBLIC_HTTP=$HTTP"
[[ "$HTTP" == "200" ]]
grep -q '/assets/images/logo_icon/logo.png' "$HTML"
grep -q '📞 اتصل' "$HTML"
grep -q 'ابدأ نقلتك' "$HTML"
grep -q 'renderOffers(data.offers' "$HTML"
echo "PUBLIC_UI=PASS"

echo "[5/6] End-to-end API workflow..."
REQ="/tmp/3asekka_final_req_$STAMP.json"
RESP="/tmp/3asekka_final_resp_$STAMP.json"
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

checks={
  "pickup": req.get("pickup"),
  "destination": req.get("destination"),
  "cargo": req.get("cargo"),
  "weightKg": req.get("weightKg"),
  "vehicleNameAr": rec.get("vehicleNameAr"),
  "distanceKm": route.get("distanceKm"),
  "estimatedFare": pricing.get("estimatedFare"),
  "offers": len(offers),
}
print("WORKFLOW_DATA="+json.dumps(checks,ensure_ascii=False))
if not req.get("pickup"): raise SystemExit("pickup missing")
if not req.get("destination"): raise SystemExit("destination missing")
if req.get("weightKg") is None: raise SystemExit("weight missing")
if not rec.get("vehicleNameAr"): raise SystemExit("vehicle missing")
if route.get("distanceKm") is None: raise SystemExit("distance missing")
if pricing.get("estimatedFare") is None: raise SystemExit("fare missing")
if len(offers) < 3: raise SystemExit(f"offers missing: {len(offers)}")
print("PUBLIC_WORKFLOW=PASS")
print("PUBLIC_OFFERS="+str(len(offers)))
PY

echo "[6/6] Health..."
HEALTH="$(curl -k -sS -o /tmp/3asekka_final_health_$STAMP.json -w '%{http_code}' https://3asekka.com/agent/health)"
echo "PUBLIC_HEALTH_HTTP=$HEALTH"
[[ "$HEALTH" == "200" ]]

trap - ERR
echo
echo "======================================"
echo "PATCH=PASS"
echo "DEPLOY_OK=YES"
echo "PRODUCTION_LOGO=YES"
echo "WORKFLOW_COMPLETE=YES"
echo "DRIVER_OFFERS=YES"
echo "FINAL_URL=https://3asekka.com/agent"
echo "======================================"

#!/usr/bin/env bash
set -euo pipefail

APP="/opt/3asekka-ai-agent/source"
STAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP="/opt/3asekka-ai-agent/backups/full_workflow_$STAMP"

AGENT_URL="https://raw.githubusercontent.com/SAMA10000/3asekka-case-study/e8afaf42ea927d6e32af323d367d3e766fb7e60e/hackathon-agent/agent.mjs"
SERVER_URL="https://raw.githubusercontent.com/SAMA10000/3asekka-case-study/4852222c7ee35b9380364f2a87418153ac5631b5/hackathon-agent/server.mjs"
INDEX_URL="https://raw.githubusercontent.com/SAMA10000/3asekka-case-study/53702c6e44069f24469322136f7a1d4480d6736f/hackathon-agent/public/index.html"
FALLBACK_URL="https://raw.githubusercontent.com/SAMA10000/3asekka-case-study/a8217340a34b8c7f8ba886f7dedccf6e7a8133e8/hackathon-agent/public/browser-fallback.js"

echo "=== 3ASEKKA FULL WORKFLOW FINAL PATCH ==="

mkdir -p "$BACKUP"
cp -a "$APP/agent.mjs" "$BACKUP/agent.mjs"
cp -a "$APP/server.mjs" "$BACKUP/server.mjs"
cp -a "$APP/public/index.html" "$BACKUP/index.html"
cp -a "$APP/public/browser-fallback.js" "$BACKUP/browser-fallback.js"

rollback() {
  rc=$?
  echo "PATCH=FAIL rc=$rc"
  cp -a "$BACKUP/agent.mjs" "$APP/agent.mjs" || true
  cp -a "$BACKUP/server.mjs" "$APP/server.mjs" || true
  cp -a "$BACKUP/index.html" "$APP/public/index.html" || true
  cp -a "$BACKUP/browser-fallback.js" "$APP/public/browser-fallback.js" || true
  systemctl restart 3asekka-ai-agent >/dev/null 2>&1 || true
  echo "ROLLBACK_ATTEMPTED=YES"
  exit "$rc"
}
trap rollback ERR

echo "[1/6] Publishing current agent + UI..."
curl -fsSL "$AGENT_URL" -o "$APP/agent.mjs"
curl -fsSL "$SERVER_URL" -o "$APP/server.mjs"
curl -fsSL "$INDEX_URL" -o "$APP/public/index.html"
curl -fsSL "$FALLBACK_URL" -o "$APP/public/browser-fallback.js"

node --check "$APP/agent.mjs"
node --check "$APP/server.mjs"
node --check "$APP/public/browser-fallback.js"

grep -q 'createSimulatedOffers' "$APP/agent.mjs"
grep -q 'location.pathname.startsWith("/ai-agent/")' "$APP/public/index.html"
grep -q 'createOffers' "$APP/public/browser-fallback.js"
echo "FILES=PASS"

echo "[2/6] Restarting agent..."
systemctl restart 3asekka-ai-agent

READY=0
for i in $(seq 1 20); do
  if curl -fsS http://127.0.0.1:3300/health >/dev/null 2>&1; then
    READY=1
    break
  fi
  sleep 1
done
if [[ "$READY" != "1" ]]; then
  journalctl -u 3asekka-ai-agent -n 80 --no-pager || true
  exit 1
fi
echo "LOCAL_HEALTH=PASS"

echo "[3/6] Local workflow test..."
REQ="/tmp/3asekka_req_$STAMP.json"
LOCAL_RESP="/tmp/3asekka_local_resp_$STAMP.json"

cat > "$REQ" <<'JSON'
{"input":"عايز أنقل 20 كرتونة من سموحة للمنشية بكرة الساعة 3، وزنهم حوالي 250 كيلو والمسافة 12 كم"}
JSON

curl -fsS   -H 'content-type: application/json'   --data-binary @"$REQ"   http://127.0.0.1:3300/api/agent   -o "$LOCAL_RESP"

python3 - "$LOCAL_RESP" <<'PY'
import json, sys
data=json.load(open(sys.argv[1],encoding="utf-8"))
offers=data.get("offers") or []
fare=(data.get("pricing") or {}).get("estimatedFare")
vehicle=(data.get("recommendation") or {}).get("vehicleNameAr")
status=data.get("status")
if len(offers) != 3:
    raise SystemExit(f"LOCAL_OFFERS_FAIL expected=3 got={len(offers)}")
if fare is None:
    raise SystemExit("LOCAL_FARE_FAIL")
print("LOCAL_WORKFLOW=PASS")
print("LOCAL_STATUS="+str(status))
print("LOCAL_VEHICLE="+str(vehicle))
print("LOCAL_FARE="+str(fare))
print("LOCAL_OFFERS=3")
PY

echo "[4/6] Public UI test..."
BUST="$(date +%s)"
PUBLIC_HTML="/tmp/3asekka_public_$STAMP.html"
PUBLIC_HTTP="$(curl -k -sS -o "$PUBLIC_HTML" -w '%{http_code}' "https://3asekka.com/ai-agent/?v=$BUST")"
echo "PUBLIC_HTTP=$PUBLIC_HTTP"
[[ "$PUBLIC_HTTP" == "200" ]]
grep -q 'location.pathname.startsWith("/ai-agent/")' "$PUBLIC_HTML"
grep -q 'عروض السائقين' "$PUBLIC_HTML"
echo "PUBLIC_UI=PASS"

echo "[5/6] Public API workflow test..."
PUBLIC_RESP="/tmp/3asekka_public_resp_$STAMP.json"
PUBLIC_API_HTTP="$(curl -k -sS   -o "$PUBLIC_RESP"   -w '%{http_code}'   -H 'content-type: application/json'   --data-binary @"$REQ"   "https://3asekka.com/ai-agent/api/agent?v=$BUST")"
echo "PUBLIC_API_HTTP=$PUBLIC_API_HTTP"
[[ "$PUBLIC_API_HTTP" == "200" ]]

python3 - "$PUBLIC_RESP" <<'PY'
import json, sys
data=json.load(open(sys.argv[1],encoding="utf-8"))
offers=data.get("offers") or []
if len(offers) != 3:
    raise SystemExit(f"PUBLIC_OFFERS_FAIL expected=3 got={len(offers)}")
print("PUBLIC_WORKFLOW=PASS")
print("PUBLIC_OFFERS=3")
PY

echo "[6/6] Public health..."
PUBLIC_HEALTH="$(curl -k -sS -o /tmp/3asekka_health_$STAMP.json -w '%{http_code}' "https://3asekka.com/ai-agent/health?v=$BUST")"
echo "PUBLIC_HEALTH_HTTP=$PUBLIC_HEALTH"
[[ "$PUBLIC_HEALTH" == "200" ]]

trap - ERR
echo
echo "======================================"
echo "PATCH=PASS"
echo "DEPLOY_OK=YES"
echo "FULL_WORKFLOW=YES"
echo "DRIVER_OFFERS=YES"
echo "OPEN=https://3asekka.com/ai-agent/?v=$BUST"
echo "======================================"

#!/usr/bin/env bash
set -euo pipefail

APP="/opt/3asekka-ai-agent/source"
STAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP="/opt/3asekka-ai-agent/backups/mobile_screen_$STAMP"
INDEX_URL="https://raw.githubusercontent.com/SAMA10000/3asekka-case-study/eb240882cb98c822b7584cc8291b52c2bbc48d1c/hackathon-agent/public/index.html"

echo "=== 3ASEKKA MOBILE APP SCREEN DEPLOY ==="

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

echo "[1/5] Publishing mobile-screen UI..."
curl -fsSL "$INDEX_URL" -o "$APP/public/index.html"

grep -q 'width: min(430px, 100vw)' "$APP/public/index.html"
grep -q 'اطلب… ونحجز لك نقلتك فورًا' "$APP/public/index.html"
grep -q '📞 اتصل' "$APP/public/index.html"
grep -q 'heroTitle: "Request it… and book your transport instantly"' "$APP/public/index.html"
grep -q 'call: "📞 Call"' "$APP/public/index.html"
echo "FILES=PASS"

echo "[2/5] Restarting agent..."
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

echo "[3/5] Testing clean public mobile UI..."
HTML="/tmp/3asekka_mobile_$STAMP.html"
HTTP="$(curl -k -sS -o "$HTML" -w '%{http_code}' https://3asekka.com/agent/)"
echo "PUBLIC_HTTP=$HTTP"
[[ "$HTTP" == "200" ]]
grep -q 'width: min(430px, 100vw)' "$HTML"
grep -q '📞 اتصل' "$HTML"
grep -q '💬 شات' "$HTML"
grep -q '🎤 فويس' "$HTML"
grep -q 'Request it… and book your transport instantly' "$HTML"
echo "PUBLIC_UI=PASS"

echo "[4/5] Testing API..."
REQ="/tmp/3asekka_mobile_req_$STAMP.json"
RESP="/tmp/3asekka_mobile_resp_$STAMP.json"
cat > "$REQ" <<'JSON'
{"input":"عايز أنقل 20 كرتونة من سموحة للمنشية وزنهم 250 كيلو والمسافة 12 كم"}
JSON
API="$(curl -k -sS -o "$RESP" -w '%{http_code}' -H 'content-type: application/json' --data-binary @"$REQ" https://3asekka.com/agent/api/agent)"
echo "PUBLIC_API_HTTP=$API"
[[ "$API" == "200" ]]

python3 - "$RESP" <<'PY'
import json, sys
d=json.load(open(sys.argv[1],encoding="utf-8"))
offers=d.get("offers") or []
if len(offers) < 3:
    raise SystemExit(f"OFFERS_FAIL got={len(offers)}")
print("PUBLIC_AGENT=PASS")
print("PUBLIC_OFFERS="+str(len(offers)))
PY

echo "[5/5] Checking health..."
HEALTH="$(curl -k -sS -o /tmp/3asekka_mobile_health_$STAMP.json -w '%{http_code}' https://3asekka.com/agent/health)"
echo "PUBLIC_HEALTH_HTTP=$HEALTH"
[[ "$HEALTH" == "200" ]]

trap - ERR
echo
echo "======================================"
echo "PATCH=PASS"
echo "DEPLOY_OK=YES"
echo "MOBILE_SCREEN=YES"
echo "ARABIC=YES"
echo "ENGLISH=YES"
echo "FINAL_URL=https://3asekka.com/agent/"
echo "======================================"

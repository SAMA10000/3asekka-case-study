#!/usr/bin/env bash
set -euo pipefail

APP="/opt/3asekka-ai-agent/source"
STAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP="/opt/3asekka-ai-agent/backups/chat_voice_call_$STAMP"
INDEX_URL="https://raw.githubusercontent.com/SAMA10000/3asekka-case-study/612be0efbfa8b485e68361c01416c326285cb6d9/hackathon-agent/public/index.html"

echo "=== 3ASEKKA CHAT + VOICE + CALL PATCH ==="

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

echo "[1/5] Publishing new interaction UI..."
curl -fsSL "$INDEX_URL" -o "$APP/public/index.html"

grep -q '💬 شات' "$APP/public/index.html"
grep -q '🎤 فويس' "$APP/public/index.html"
grep -q '📞 كلم عالسكة' "$APP/public/index.html"
grep -q 'callConversationText' "$APP/public/index.html"
grep -q 'location.pathname.startsWith("/ai-agent/")' "$APP/public/index.html"
echo "FILES=PASS"

echo "[2/5] Restarting agent..."
systemctl restart 3asekka-ai-agent

READY=0
for i in $(seq 1 20); do
  if curl -fsS http://127.0.0.1:3300/health >/dev/null 2>&1; then
    READY=1
    break
  fi
  sleep 1
done
[[ "$READY" == "1" ]]
echo "LOCAL_HEALTH=PASS"

echo "[3/5] Testing local UI..."
LOCAL_HTML="/tmp/3asekka_call_ui_$STAMP.html"
curl -fsS http://127.0.0.1:3300/ -o "$LOCAL_HTML"
grep -q '💬 شات' "$LOCAL_HTML"
grep -q '🎤 فويس' "$LOCAL_HTML"
grep -q '📞 كلم عالسكة' "$LOCAL_HTML"
grep -q 'ابدأ نقلتك' "$LOCAL_HTML"
echo "LOCAL_UI=PASS"

echo "[4/5] Testing public UI..."
BUST="$(date +%s)"
PUBLIC_HTML="/tmp/3asekka_public_call_ui_$STAMP.html"
PUBLIC_HTTP="$(curl -k -sS -o "$PUBLIC_HTML" -w '%{http_code}' "https://3asekka.com/ai-agent/?v=$BUST")"
echo "PUBLIC_HTTP=$PUBLIC_HTTP"
[[ "$PUBLIC_HTTP" == "200" ]]
grep -q '💬 شات' "$PUBLIC_HTML"
grep -q '🎤 فويس' "$PUBLIC_HTML"
grep -q '📞 كلم عالسكة' "$PUBLIC_HTML"
grep -q 'ابدأ نقلتك' "$PUBLIC_HTML"
echo "PUBLIC_UI=PASS"

echo "[5/5] Testing public agent API..."
REQ="/tmp/3asekka_call_req_$STAMP.json"
RESP="/tmp/3asekka_call_resp_$STAMP.json"
cat > "$REQ" <<'JSON'
{"input":"عايز أنقل 20 كرتونة من سموحة للمنشية وزنهم 250 كيلو والمسافة 12 كم"}
JSON

API_HTTP="$(curl -k -sS -o "$RESP" -w '%{http_code}'   -H 'content-type: application/json'   --data-binary @"$REQ"   "https://3asekka.com/ai-agent/api/agent?v=$BUST")"
echo "PUBLIC_API_HTTP=$API_HTTP"
[[ "$API_HTTP" == "200" ]]

python3 - "$RESP" <<'PY'
import json, sys
data=json.load(open(sys.argv[1],encoding="utf-8"))
offers=data.get("offers") or []
if len(offers) < 3:
    raise SystemExit(f"OFFERS_FAIL got={len(offers)}")
print("PUBLIC_AGENT=PASS")
print("PUBLIC_OFFERS="+str(len(offers)))
PY

trap - ERR
echo
echo "======================================"
echo "PATCH=PASS"
echo "DEPLOY_OK=YES"
echo "CHAT=YES"
echo "VOICE=YES"
echo "CALL=YES"
echo "OPEN=https://3asekka.com/ai-agent/?v=$BUST"
echo "======================================"

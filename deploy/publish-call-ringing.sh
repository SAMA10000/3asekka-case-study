#!/usr/bin/env bash
set -euo pipefail

APP="/opt/3asekka-ai-agent/source"
STAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP="/opt/3asekka-ai-agent/backups/call_ringing_$STAMP"
INDEX_URL="https://raw.githubusercontent.com/SAMA10000/3asekka-case-study/8cda8a3b3bcbbda15619d01923e3a5ade8bb0fc0/hackathon-agent/public/index.html"

echo "=== 3ASEKKA CALL RINGING PATCH ==="

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

echo "[1/4] Publishing ringing + hangup UI..."
curl -fsSL "$INDEX_URL" -o "$APP/public/index.html"

grep -q 'playRingback' "$APP/public/index.html"
grep -q 'playHangupTone' "$APP/public/index.html"
grep -q 'بيرن على عالسكة' "$APP/public/index.html"
echo "FILES=PASS"

echo "[2/4] Restarting agent..."
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

echo "[3/4] Verifying public UI..."
BUST="$(date +%s)"
PUBLIC_HTML="/tmp/3asekka_ring_ui_$STAMP.html"
PUBLIC_HTTP="$(curl -k -sS -o "$PUBLIC_HTML" -w '%{http_code}' "https://3asekka.com/ai-agent/?v=$BUST")"
echo "PUBLIC_HTTP=$PUBLIC_HTTP"
[[ "$PUBLIC_HTTP" == "200" ]]
grep -q 'playRingback' "$PUBLIC_HTML"
grep -q 'playHangupTone' "$PUBLIC_HTML"
grep -q '📞 كلم عالسكة' "$PUBLIC_HTML"
echo "PUBLIC_UI=PASS"

echo "[4/4] Verifying public API..."
API_HTTP="$(curl -k -sS -o /tmp/3asekka_ring_api_$STAMP.json -w '%{http_code}' "https://3asekka.com/ai-agent/health?v=$BUST")"
echo "PUBLIC_HEALTH_HTTP=$API_HTTP"
[[ "$API_HTTP" == "200" ]]

trap - ERR
echo
echo "======================================"
echo "PATCH=PASS"
echo "DEPLOY_OK=YES"
echo "RINGBACK=YES"
echo "HANGUP_TONE=YES"
echo "OPEN=https://3asekka.com/ai-agent/?v=$BUST"
echo "======================================"

#!/usr/bin/env bash
set -euo pipefail

SITE="/etc/nginx/sites-available/3asekka.com"

echo "=== 3ASEKKA CLEAN URL FINALIZE ==="

echo "[1/5] Checking nginx clean route..."
if ! grep -q 'location ^~ /agent/' "$SITE"; then
  echo "CLEAN_ROUTE_MISSING"
  exit 1
fi
nginx -t
systemctl reload nginx
echo "NGINX=PASS"

echo "[2/5] Restarting agent and waiting..."
systemctl restart 3asekka-ai-agent

READY=0
for i in $(seq 1 30); do
  if curl -fsS http://127.0.0.1:3300/health >/dev/null 2>&1; then
    READY=1
    break
  fi
  sleep 1
done

if [[ "$READY" != "1" ]]; then
  echo "AGENT_NOT_READY"
  systemctl status 3asekka-ai-agent --no-pager || true
  journalctl -u 3asekka-ai-agent -n 80 --no-pager || true
  exit 1
fi
echo "LOCAL_HEALTH=PASS"

echo "[3/5] Checking clean public page..."
HTML="/tmp/3asekka_agent_clean.html"
HTTP="$(curl -k -sS -o "$HTML" -w '%{http_code}' https://3asekka.com/agent/)"
echo "PUBLIC_HTTP=$HTTP"
[[ "$HTTP" == "200" ]]
grep -q '💬 شات' "$HTML"
grep -q '🎤 فويس' "$HTML"
grep -q '📞 كلم عالسكة' "$HTML"
grep -q 'playRingback' "$HTML"
echo "PUBLIC_UI=PASS"

echo "[4/5] Checking clean health endpoint..."
HEALTH="$(curl -k -sS -o /tmp/3asekka_agent_health.json -w '%{http_code}' https://3asekka.com/agent/health)"
echo "PUBLIC_HEALTH_HTTP=$HEALTH"
[[ "$HEALTH" == "200" ]]

echo "[5/5] Checking clean API + offers..."
REQ="/tmp/3asekka_clean_req.json"
RESP="/tmp/3asekka_clean_resp.json"
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

echo
echo "======================================"
echo "PATCH=PASS"
echo "DEPLOY_OK=YES"
echo "CLEAN_URL=YES"
echo "FINAL_URL=https://3asekka.com/agent/"
echo "======================================"

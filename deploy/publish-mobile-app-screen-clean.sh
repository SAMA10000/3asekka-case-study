#!/usr/bin/env bash
set -euo pipefail

APP="/opt/3asekka-ai-agent/source"
SITE="/etc/nginx/sites-available/3asekka.com"
STAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP="/opt/3asekka-ai-agent/backups/mobile_exact_$STAMP"
INDEX_URL="https://raw.githubusercontent.com/SAMA10000/3asekka-case-study/eb240882cb98c822b7584cc8291b52c2bbc48d1c/hackathon-agent/public/index.html"

echo "=== 3ASEKKA MOBILE SCREEN CLEAN URL FINAL ==="

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

echo "[1/6] Publishing bilingual mobile UI..."
curl -fsSL "$INDEX_URL" -o "$APP/public/index.html"

grep -q 'width: min(430px, 100vw)' "$APP/public/index.html"
grep -q 'اطلب… ونحجز لك نقلتك فورًا' "$APP/public/index.html"
grep -q '📞 اتصل' "$APP/public/index.html"
grep -q 'Request it… and book your transport instantly' "$APP/public/index.html"
grep -q 'call: "📞 Call"' "$APP/public/index.html"
echo "FILES=PASS"

echo "[2/6] Adding exact clean /agent route..."
python3 - "$SITE" <<'PY'
from pathlib import Path
import sys

p=Path(sys.argv[1])
s=p.read_text(encoding="utf-8")
marker="location = /agent {"

if marker not in s:
    needle="    location ^~ /agent/ {"
    pos=s.find(needle)
    if pos < 0:
        raise SystemExit("missing existing /agent/ nginx location")

    block='''    location = /agent {
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
    s=s[:pos]+block+s[pos:]
    p.write_text(s,encoding="utf-8")
PY

nginx -t
systemctl reload nginx
echo "NGINX=PASS"

echo "[3/6] Restarting agent and waiting..."
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

echo "[4/6] Verifying origin UI..."
LOCAL="/tmp/3asekka_mobile_local_$STAMP.html"
curl -fsS http://127.0.0.1:3300/ -o "$LOCAL"
grep -q 'width: min(430px, 100vw)' "$LOCAL"
grep -q '📞 اتصل' "$LOCAL"
grep -q 'Request it… and book your transport instantly' "$LOCAL"
echo "LOCAL_UI=PASS"

echo "[5/6] Verifying exact clean public URL..."
PUB="/tmp/3asekka_mobile_public_$STAMP.html"
HDR="/tmp/3asekka_mobile_public_$STAMP.headers"
HTTP="$(curl -k -sS -D "$HDR" -o "$PUB" -w '%{http_code}' https://3asekka.com/agent)"
echo "PUBLIC_HTTP=$HTTP"
[[ "$HTTP" == "200" ]]
grep -q 'width: min(430px, 100vw)' "$PUB"
grep -q '📞 اتصل' "$PUB"
grep -q 'Request it… and book your transport instantly' "$PUB"
echo "PUBLIC_UI=PASS"

echo "[6/6] Verifying API and offers..."
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

trap - ERR
echo
echo "======================================"
echo "PATCH=PASS"
echo "DEPLOY_OK=YES"
echo "MOBILE_SCREEN=YES"
echo "ARABIC=YES"
echo "ENGLISH=YES"
echo "CLEAN_URL=YES"
echo "FINAL_URL=https://3asekka.com/agent"
echo "======================================"

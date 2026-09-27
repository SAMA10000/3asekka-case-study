#!/usr/bin/env bash
set -euo pipefail

PORT=3300
NGINX_SITE="/etc/nginx/sites-available/3asekka.com"
STAMP="$(date +%Y%m%d_%H%M%S)"
NGINX_BACKUP="${NGINX_SITE}.bak_ai_${STAMP}"

if [[ $EUID -ne 0 ]]; then
  echo "Run as root."
  exit 1
fi

echo "=== 3ASEKKA AI PUBLIC ROUTE FINISH ==="

if [[ ! -f "$NGINX_SITE" ]]; then
  echo "PATCH=FAIL"
  echo "Missing Nginx vhost: $NGINX_SITE"
  exit 1
fi

if ! systemctl is-active --quiet 3asekka-ai-agent; then
  echo "PATCH=FAIL"
  echo "3asekka-ai-agent service is not active."
  systemctl status 3asekka-ai-agent --no-pager -l || true
  exit 1
fi

echo "SERVICE=ACTIVE"

HEALTH_OK=0
for i in $(seq 1 15); do
  if curl -fsS "http://127.0.0.1:${PORT}/health" >/tmp/3asekka_ai_health.json 2>/dev/null; then
    HEALTH_OK=1
    break
  fi
  sleep 1
done

if [[ "$HEALTH_OK" != "1" ]]; then
  echo "PATCH=FAIL"
  echo "Local health endpoint did not become ready."
  journalctl -u 3asekka-ai-agent -n 80 --no-pager || true
  exit 1
fi

echo "LOCAL_HEALTH=PASS"

AI_JSON="$(curl -fsS "http://127.0.0.1:${PORT}/api/ai-test")"
python3 - "$AI_JSON" <<'PY'
import json, sys
data = json.loads(sys.argv[1])
probe = data.get("probe") or {}
if probe.get("used") is not True:
    raise SystemExit("AI probe failed: " + str(probe.get("error") or probe))
print("AI_PROBE=PASS")
print("AI_PROVIDER=" + str(probe.get("provider")))
print("AI_MODEL=" + str(probe.get("model")))
PY

cp -a "$NGINX_SITE" "$NGINX_BACKUP"
echo "NGINX_BACKUP=$NGINX_BACKUP"

rollback() {
  rc=$?
  echo "PATCH=FAIL rc=$rc"
  cp -a "$NGINX_BACKUP" "$NGINX_SITE" || true
  nginx -t >/dev/null 2>&1 && systemctl reload nginx >/dev/null 2>&1 || true
  echo "ROLLBACK_ATTEMPTED=YES"
  exit "$rc"
}
trap rollback ERR

python3 - "$NGINX_SITE" <<'PY'
import sys, re

path = sys.argv[1]
text = open(path, encoding="utf-8").read()

blocks = []
pos = 0
while True:
    m = re.search(r"\bserver\s*\{", text[pos:])
    if not m:
        break
    start = pos + m.start()
    brace = text.find("{", start)
    depth = 0
    end = None
    for j in range(brace, len(text)):
        ch = text[j]
        if ch == "{":
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                end = j
                break
    if end is None:
        raise SystemExit("Could not parse Nginx server block")
    block = text[start:end+1]
    blocks.append((start, end, block))
    pos = end + 1

candidates = []
for start, end, block in blocks:
    if re.search(r"server_name[^;]*\b3asekka\.com\b", block):
        score = 0
        if re.search(r"listen\s+443\b", block): score += 100
        if re.search(r"listen\s+\[::\]:443\b", block): score += 100
        if "ssl" in block: score += 20
        candidates.append((score, start, end, block))

if not candidates:
    raise SystemExit("No 3asekka.com server block found")

score, start, end, block = max(candidates, key=lambda x: x[0])
if score < 100:
    raise SystemExit("Could not identify HTTPS 3asekka.com server block")

if re.search(r"location\s+\^~\s+/ai/\s*\{", block):
    print("NGINX_AI_LOCATION=ALREADY_PRESENT")
    raise SystemExit(0)

location_block = r'''
    # 3ASEKKA AI Transport Agent
    location ^~ /ai/ {
        proxy_pass http://127.0.0.1:3300/;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 120s;
        proxy_send_timeout 120s;
    }

'''

text = text[:end] + location_block + text[end:]
open(path, "w", encoding="utf-8").write(text)
print("NGINX_AI_LOCATION=ADDED")
PY

nginx -t
systemctl reload nginx

PUBLIC_CODE="$(curl -k -sS -o /tmp/3asekka_ai_public.html -w '%{http_code}' https://3asekka.com/ai/ || true)"
echo "PUBLIC_HTTP=$PUBLIC_CODE"

if [[ "$PUBLIC_CODE" != "200" ]]; then
  echo "Public page verification failed."
  exit 1
fi

if ! grep -q "3ASEKKA" /tmp/3asekka_ai_public.html; then
  echo "Public page returned 200 but 3ASEKKA marker was not found."
  exit 1
fi

PUBLIC_HEALTH_CODE="$(curl -k -sS -o /tmp/3asekka_ai_public_health.json -w '%{http_code}' https://3asekka.com/ai/health || true)"
echo "PUBLIC_HEALTH_HTTP=$PUBLIC_HEALTH_CODE"
if [[ "$PUBLIC_HEALTH_CODE" != "200" ]]; then
  echo "Public health endpoint verification failed."
  exit 1
fi

trap - ERR
echo "PATCH=PASS"
echo "DEPLOY_OK=YES"
echo "OPEN=https://3asekka.com/ai/"

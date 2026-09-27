#!/usr/bin/env bash
set -euo pipefail

NGINX_SITE="/etc/nginx/sites-available/3asekka.com"
PORT=3300
STAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP="${NGINX_SITE}.bak_ai_public_${STAMP}"

if [[ $EUID -ne 0 ]]; then
  echo "Run as root."
  exit 1
fi

echo "=== 3ASEKKA AI PUBLIC PATH PATCH ==="

if [[ ! -f "$NGINX_SITE" ]]; then
  echo "PATCH=FAIL missing_vhost"
  exit 1
fi

if ! systemctl is-active --quiet 3asekka-ai-agent; then
  echo "PATCH=FAIL agent_not_running"
  systemctl status 3asekka-ai-agent --no-pager -l || true
  exit 1
fi

curl -fsS "http://127.0.0.1:${PORT}/health" >/dev/null
echo "LOCAL_AGENT=PASS"

cp -a "$NGINX_SITE" "$BACKUP"
echo "BACKUP=$BACKUP"

rollback() {
  rc=$?
  echo "PATCH=FAIL rc=$rc"
  cp -a "$BACKUP" "$NGINX_SITE" || true
  nginx -t >/dev/null 2>&1 && systemctl reload nginx >/dev/null 2>&1 || true
  echo "ROLLBACK_ATTEMPTED=YES"
  exit "$rc"
}
trap rollback ERR

python3 - "$NGINX_SITE" <<'PY'
import re, sys

path = sys.argv[1]
text = open(path, encoding="utf-8").read()

# Find top-level server blocks and choose the HTTPS block for 3asekka.com.
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
        if text[j] == "{":
            depth += 1
        elif text[j] == "}":
            depth -= 1
            if depth == 0:
                end = j
                break
    if end is None:
        raise SystemExit("Could not parse Nginx server block")
    blocks.append((start, end, text[start:end+1]))
    pos = end + 1

candidates = []
for start, end, block in blocks:
    if re.search(r"server_name[^;]*\b3asekka\.com\b", block):
        score = 0
        if re.search(r"listen\s+443\b", block): score += 100
        if "ssl" in block: score += 20
        candidates.append((score, start, end, block))

if not candidates:
    raise SystemExit("No 3asekka.com server block found")

score, start, end, block = max(candidates, key=lambda x: x[0])
if score < 100:
    raise SystemExit("HTTPS 3asekka.com server block not found")

location_block = r'''
    # 3ASEKKA AI Transport Agent - public uncached path
    location ^~ /ai-agent/ {
        proxy_pass http://127.0.0.1:3300/;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 120s;
        proxy_send_timeout 120s;
        add_header Cache-Control "no-store, no-cache, must-revalidate, max-age=0" always;
        add_header CDN-Cache-Control "no-store" always;
        add_header Surrogate-Control "no-store" always;
    }

'''

if re.search(r"location\s+\^~\s+/ai-agent/\s*\{", block):
    print("AI_AGENT_LOCATION=ALREADY_PRESENT")
else:
    text = text[:end] + location_block + text[end:]
    open(path, "w", encoding="utf-8").write(text)
    print("AI_AGENT_LOCATION=ADDED")
PY

nginx -t
systemctl reload nginx
echo "NGINX_RELOAD=PASS"

# Use a cache-busting query on first verification so Cloudflare must request the new path.
TEST_URL="https://3asekka.com/ai-agent/?deploy=${STAMP}"
CODE="$(curl -k -sS -o /tmp/3asekka_ai_agent_public.html -w '%{http_code}' "$TEST_URL" || true)"
echo "PUBLIC_HTTP=$CODE"

if [[ "$CODE" != "200" ]]; then
  echo "PUBLIC_TEST=FAIL"
  exit 1
fi

if ! grep -q "3ASEKKA" /tmp/3asekka_ai_agent_public.html; then
  echo "PUBLIC_MARKER=FAIL"
  echo "FIRST_300_BYTES:"
  head -c 300 /tmp/3asekka_ai_agent_public.html || true
  echo
  exit 1
fi

echo "PUBLIC_MARKER=PASS"

HEADERS="$(curl -k -sSI "$TEST_URL" || true)"
printf '%s\n' "$HEADERS" | grep -iE '^(HTTP/|cf-cache-status:|cache-control:|cdn-cache-control:)' || true

trap - ERR
echo "PATCH=PASS"
echo "DEPLOY_OK=YES"
echo "OPEN=https://3asekka.com/ai-agent/"

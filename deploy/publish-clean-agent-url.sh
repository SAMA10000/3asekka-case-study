#!/usr/bin/env bash
set -e

APP="/opt/3asekka-ai-agent/source"
SITE="/etc/nginx/sites-available/3asekka.com"
INDEX_URL="https://raw.githubusercontent.com/SAMA10000/3asekka-case-study/5387af459da67af52f68163f47d09b28c01b65db/hackathon-agent/public/index.html"

cp "$APP/public/index.html" "$APP/public/index.html.bak_clean"
cp "$SITE" "$SITE.bak_clean"

curl -fsSL "$INDEX_URL" -o "$APP/public/index.html"

python3 - "$SITE" <<'PY'
from pathlib import Path
import sys
p=Path(sys.argv[1])
s=p.read_text()
if "location ^~ /agent/" not in s:
    needle="    location ^~ /ai-agent/ {"
    if needle not in s:
        raise SystemExit("missing /ai-agent/ location")
    block='''    location ^~ /agent/ {
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
        add_header Cloudflare-CDN-Cache-Control "no-store" always;
        add_header Surrogate-Control "no-store" always;
    }

'''
    s=s.replace(needle, block+needle, 1)
    p.write_text(s)
PY

nginx -t
systemctl reload nginx
systemctl restart 3asekka-ai-agent

curl -fsS http://127.0.0.1:3300/health >/dev/null
curl -kfsS https://3asekka.com/agent/ | grep -q 'كلم عالسكة'
curl -kfsS https://3asekka.com/agent/health >/dev/null

echo "PATCH=PASS"
echo "DEPLOY_OK=YES"
echo "CLEAN_URL=YES"
echo "FINAL_URL=https://3asekka.com/agent/"

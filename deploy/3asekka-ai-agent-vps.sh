#!/usr/bin/env bash
set -euo pipefail

REPO_TARBALL="https://github.com/SAMA10000/3asekka-case-study/archive/refs/heads/main.tar.gz"
APP_ROOT="/opt/3asekka-ai-agent"
SRC_DIR="$APP_ROOT/source"
ENV_FILE="/etc/3asekka-ai-agent.env"
SERVICE_FILE="/etc/systemd/system/3asekka-ai-agent.service"
PORT="3300"

NGINX_SITE="$(grep -RIlE 'server_name[^;]*3asekka\\.com' /etc/nginx/sites-enabled /etc/nginx/sites-available 2>/dev/null | head -n1 || true)"
if [[ -z "$NGINX_SITE" || ! -f "$NGINX_SITE" ]]; then
  echo "Could not locate the active Nginx vhost containing server_name 3asekka.com"
  exit 1
fi
NGINX_BACKUP="${NGINX_SITE}.bak.$(date +%Y%m%d_%H%M%S)"

if [[ $EUID -ne 0 ]]; then
  echo "Run as root."
  exit 1
fi

if ! command -v node >/dev/null 2>&1; then
  echo "Node.js 18+ is required before deployment."
  exit 1
fi

NODE_MAJOR="$(node -p 'process.versions.node.split(".")[0]')"
if [[ "$NODE_MAJOR" -lt 18 ]]; then
  echo "Node.js 18+ is required. Current: $(node -v)"
  exit 1
fi

echo "NGINX_SITE=$NGINX_SITE"
mkdir -p "$APP_ROOT"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "Downloading current public hackathon agent..."
curl -fsSL "$REPO_TARBALL" -o "$TMP/repo.tar.gz"
tar -xzf "$TMP/repo.tar.gz" -C "$TMP"
EXTRACTED="$(find "$TMP" -maxdepth 1 -type d -name '3asekka-case-study-*' | head -n1)"

rm -rf "$SRC_DIR"
mkdir -p "$SRC_DIR"
cp -a "$EXTRACTED/hackathon-agent/." "$SRC_DIR/"

if [[ ! -f "$ENV_FILE" ]]; then
  echo
  echo "Gemini key will be stored only on this server in $ENV_FILE."
  read -r -s -p "Paste Gemini API key: " GEMINI_KEY
  echo
  umask 077
  cat > "$ENV_FILE" <<EOF
PORT=$PORT
GEMINI_API_KEY=$GEMINI_KEY
GEMINI_MODEL=gemini-3.8-flash
EOF
  unset GEMINI_KEY
  chmod 600 "$ENV_FILE"
fi

cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=3ASEKKA AI Transport Agent
After=network.target

[Service]
Type=simple
WorkingDirectory=$SRC_DIR
EnvironmentFile=$ENV_FILE
ExecStart=$(command -v node) $SRC_DIR/server.mjs
Restart=always
RestartSec=3
User=root

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable 3asekka-ai-agent >/dev/null 2>&1 || true
systemctl restart 3asekka-ai-agent
sleep 2

curl -fsS "http://127.0.0.1:$PORT/health" >/dev/null

cp -a "$NGINX_SITE" "$NGINX_BACKUP"

python3 - "$NGINX_SITE" <<'PY'
import sys, re
path = sys.argv[1]
text = open(path, encoding="utf-8").read()
if "location ^~ /ai/" in text:
    print("Nginx /ai/ location already exists.")
    raise SystemExit(0)

m = re.search(r"server\s*\{", text)
if not m:
    raise SystemExit("Could not find Nginx server block")

i = m.start()
depth = 0
end = None
for j in range(m.start(), len(text)):
    ch = text[j]
    if ch == "{":
        depth += 1
    elif ch == "}":
        depth -= 1
        if depth == 0:
            end = j
            break

if end is None:
    raise SystemExit("Could not find end of Nginx server block")

block = r'''
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
text = text[:end] + block + text[end:]
open(path, "w", encoding="utf-8").write(text)
print("Added /ai/ reverse proxy.")
PY

if ! nginx -t; then
  echo "Nginx test failed. Restoring backup."
  cp -a "$NGINX_BACKUP" "$NGINX_SITE"
  nginx -t
  exit 1
fi

systemctl reload nginx

echo
echo "=== VERIFY ==="
curl -fsS "http://127.0.0.1:$PORT/health"
echo
HTTP_CODE="$(curl -k -sS -o /tmp/3asekka_ai_verify.html -w '%{http_code}' https://3asekka.com/ai/ || true)"
echo "PUBLIC_HTTP=$HTTP_CODE"
if [[ "$HTTP_CODE" != "200" ]]; then
  echo "Public /ai/ verification failed. Nginx backup kept at: $NGINX_BACKUP"
  exit 1
fi

echo "DEPLOY_OK=YES"
echo "Open: https://3asekka.com/ai/"
echo "Service: systemctl status 3asekka-ai-agent --no-pager"

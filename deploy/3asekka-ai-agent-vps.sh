#!/usr/bin/env bash
set -euo pipefail

REPO_TARBALL="https://github.com/SAMA10000/3asekka-case-study/archive/refs/heads/main.tar.gz"
APP_ROOT="/opt/3asekka-ai-agent"
SRC_DIR="$APP_ROOT/source"
ENV_FILE="/etc/3asekka-ai-agent.env"
SERVICE_FILE="/etc/systemd/system/3asekka-ai-agent.service"
NGINX_SITE="/etc/nginx/sites-available/3asekka.com"
NGINX_BACKUP="/etc/nginx/sites-available/3asekka.com.bak.$(date +%Y%m%d_%H%M%S)"
PORT="3300"

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

if [[ ! -f "$NGINX_SITE" ]]; then
  echo "Expected Nginx site not found: $NGINX_SITE"
  exit 1
fi

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
systemctl enable --now 3asekka-ai-agent
sleep 1

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
echo "Deployment complete."
echo "Open: https://3asekka.com/ai/"
echo "Service: systemctl status 3asekka-ai-agent --no-pager"

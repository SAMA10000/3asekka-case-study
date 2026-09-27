#!/usr/bin/env bash
set -euo pipefail

REPO_TARBALL="https://github.com/SAMA10000/3asekka-case-study/archive/refs/heads/main.tar.gz"
APP_ROOT="/opt/3asekka-ai-agent"
SRC_DIR="$APP_ROOT/source"
ENV_FILE="/etc/3asekka-ai-agent.env"
SERVICE_FILE="/etc/systemd/system/3asekka-ai-agent.service"
PORT="3300"
STAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP_DIR="$APP_ROOT/backups/$STAMP"

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
mkdir -p "$APP_ROOT" "$BACKUP_DIR"

HAD_OLD_SOURCE=0
HAD_OLD_SERVICE=0
HAD_OLD_NGINX=0

if [[ -d "$SRC_DIR" ]]; then
  cp -a "$SRC_DIR" "$BACKUP_DIR/source"
  HAD_OLD_SOURCE=1
fi
if [[ -f "$SERVICE_FILE" ]]; then
  cp -a "$SERVICE_FILE" "$BACKUP_DIR/3asekka-ai-agent.service"
  HAD_OLD_SERVICE=1
fi

rollback() {
  rc=$?
  echo "PATCH=FAIL rc=$rc"
  set +e
  if [[ "$HAD_OLD_SOURCE" == "1" && -d "$BACKUP_DIR/source" ]]; then
    rm -rf "$SRC_DIR"
    cp -a "$BACKUP_DIR/source" "$SRC_DIR"
  fi
  if [[ "$HAD_OLD_SERVICE" == "1" && -f "$BACKUP_DIR/3asekka-ai-agent.service" ]]; then
    cp -a "$BACKUP_DIR/3asekka-ai-agent.service" "$SERVICE_FILE"
  fi
  if [[ "$HAD_OLD_NGINX" == "1" && -f "$NGINX_BACKUP" ]]; then
    cp -a "$NGINX_BACKUP" "$NGINX_SITE"
  fi
  systemctl daemon-reload >/dev/null 2>&1 || true
  systemctl restart 3asekka-ai-agent >/dev/null 2>&1 || true
  nginx -t >/dev/null 2>&1 && systemctl reload nginx >/dev/null 2>&1 || true
  echo "ROLLBACK_ATTEMPTED=YES"
  exit "$rc"
}
trap rollback ERR
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

if ss -ltn 2>/dev/null | grep -qE '[:.]3300[[:space:]]'; then
  if ! systemctl is-active --quiet 3asekka-ai-agent 2>/dev/null; then
    echo "Port 3300 is already in use by another service. Aborting."
    exit 1
  fi
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
HAD_OLD_NGINX=1

python3 - "$NGINX_SITE" <<'PY'
import sys, re

path = sys.argv[1]
text = open(path, encoding="utf-8").read()

# Locate top-level server blocks.
blocks = []
i = 0
while True:
    m = re.search(r"\bserver\s*\{", text[i:])
    if not m:
        break
    start = i + m.start()
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
    i = end + 1

candidates = []
for start, end, block in blocks:
    if re.search(r"server_name[^;]*\b3asekka\.com\b", block):
        score = 0
        if re.search(r"listen\s+443\b", block): score += 10
        if "ssl" in block: score += 5
        candidates.append((score, start, end, block))

if not candidates:
    raise SystemExit("No server block for 3asekka.com found")

_, start, end, block = sorted(candidates, reverse=True)[0]

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

if re.search(r"location\s+\^~\s+/ai/\s*\{", block):
    print("Nginx /ai/ location already exists in the 3asekka.com server block.")
else:
    text = text[:end] + location_block + text[end:]
    open(path, "w", encoding="utf-8").write(text)
    print("Added /ai/ reverse proxy to the 3asekka.com HTTPS server block.")
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

trap - ERR
echo "PATCH=PASS"
echo "DEPLOY_OK=YES"
echo "Open: https://3asekka.com/ai/"
echo "Service: systemctl status 3asekka-ai-agent --no-pager"

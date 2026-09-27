#!/usr/bin/env bash
set -euo pipefail

APP="/opt/3asekka-ai-agent/source"
STAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP="/opt/3asekka-ai-agent/backups/logo_workflow_$STAMP"
INDEX_URL="https://raw.githubusercontent.com/SAMA10000/3asekka-case-study/d4ec5c4ae8a76c21e61c018d15244e18994b786b/hackathon-agent/public/index.html"
SERVER_URL="https://raw.githubusercontent.com/SAMA10000/3asekka-case-study/69dc9caa12cd4cbf81b78e95067e2aefd7b24d78/hackathon-agent/server.mjs"

echo "=== 3ASEKKA LOGO + WORKFLOW FINAL FIX ==="

mkdir -p "$BACKUP"
cp -a "$APP/public/index.html" "$BACKUP/index.html"
cp -a "$APP/server.mjs" "$BACKUP/server.mjs"
if [[ -f "$APP/public/3asekka-logo.png" ]]; then
  cp -a "$APP/public/3asekka-logo.png" "$BACKUP/3asekka-logo.png"
fi

rollback() {
  rc=$?
  echo "PATCH=FAIL rc=$rc"
  cp -a "$BACKUP/index.html" "$APP/public/index.html" || true
  cp -a "$BACKUP/server.mjs" "$APP/server.mjs" || true
  if [[ -f "$BACKUP/3asekka-logo.png" ]]; then
    cp -a "$BACKUP/3asekka-logo.png" "$APP/public/3asekka-logo.png" || true
  fi
  systemctl restart 3asekka-ai-agent >/dev/null 2>&1 || true
  echo "ROLLBACK_ATTEMPTED=YES"
  exit "$rc"
}
trap rollback ERR

echo "[1/7] Publishing corrected UI + server..."
curl -fsSL "$INDEX_URL" -o "$APP/public/index.html"
curl -fsSL "$SERVER_URL" -o "$APP/server.mjs"
node --check "$APP/server.mjs"
grep -q '/agent/3asekka-logo.png' "$APP/public/index.html"
grep -q 'pathname === "/3asekka-logo.png"' "$APP/server.mjs"
echo "FILES=PASS"

echo "[2/7] Discovering the logo used by the main 3ASEKKA site..."
HOME="/tmp/3asekka_home_$STAMP.html"
CANDS="/tmp/3asekka_logo_candidates_$STAMP.txt"
curl -kfsSL https://3asekka.com/ -o "$HOME"

python3 - "$HOME" "$CANDS" <<'PY'
from html.parser import HTMLParser
from urllib.parse import urljoin
import sys, re

html_path, out_path = sys.argv[1], sys.argv[2]
base = "https://3asekka.com/"
class P(HTMLParser):
    def __init__(self):
        super().__init__()
        self.items=[]
    def handle_starttag(self, tag, attrs):
        if tag.lower()!="img":
            return
        d=dict(attrs)
        src=d.get("src") or d.get("data-src") or ""
        if not src:
            return
        hay=" ".join(str(d.get(k,"")) for k in ("src","alt","class","id","title")).lower()
        score=0
        if "logo" in hay: score += 10
        if "3asekka" in hay or "asekka" in hay or "sikka" in hay: score += 8
        if "عالسكة" in hay: score += 8
        if re.search(r"\.(png|webp|jpe?g)(\?|$)", src, re.I): score += 3
        self.items.append((score,urljoin(base,src)))

p=P()
p.feed(open(html_path,encoding="utf-8",errors="ignore").read())
seen=set()
rows=[]
for score,url in sorted(p.items,key=lambda x:x[0],reverse=True):
    if url not in seen:
        rows.append(url)
        seen.add(url)

# exact source asset from the 3ASEKKA production repo as fallback
rows.append("https://raw.githubusercontent.com/SAMA10000/3asekka/main/assets/images/logo_icon/logo.png")

with open(out_path,"w",encoding="utf-8") as f:
    for u in rows:
        f.write(u+"\n")
PY

FOUND=0
while IFS= read -r LOGO_URL; do
  [[ -n "$LOGO_URL" ]] || continue
  TMP="/tmp/3asekka_logo_try_$STAMP"
  CODE="$(curl -k -L -sS -o "$TMP" -w '%{http_code}' "$LOGO_URL" || true)"
  if [[ "$CODE" == "200" ]] && [[ -s "$TMP" ]]; then
    MIME="$(file -b --mime-type "$TMP" 2>/dev/null || true)"
    if [[ "$MIME" == "image/png" ]]; then
      cp "$TMP" "$APP/public/3asekka-logo.png"
      echo "LOGO_SOURCE=$LOGO_URL"
      echo "LOGO_MIME=$MIME"
      FOUND=1
      break
    fi
  fi
done < "$CANDS"

if [[ "$FOUND" != "1" ]]; then
  echo "Could not obtain the main 3ASEKKA PNG logo."
  exit 1
fi

echo "LOGO_DOWNLOAD=PASS"

echo "[3/7] Restarting agent..."
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

echo "[4/7] Testing logo through the clean agent route..."
LOGO_HTTP="$(curl -k -sS -o /tmp/3asekka_logo_public_$STAMP.png -w '%{http_code}' https://3asekka.com/agent/3asekka-logo.png)"
echo "LOGO_HTTP=$LOGO_HTTP"
[[ "$LOGO_HTTP" == "200" ]]
[[ "$(file -b --mime-type /tmp/3asekka_logo_public_$STAMP.png)" == "image/png" ]]
echo "LOGO_PUBLIC=PASS"

echo "[5/7] Testing public mobile UI..."
HTML="/tmp/3asekka_ui_$STAMP.html"
PUBLIC_HTTP="$(curl -k -sS -o "$HTML" -w '%{http_code}' https://3asekka.com/agent)"
echo "PUBLIC_HTTP=$PUBLIC_HTTP"
[[ "$PUBLIC_HTTP" == "200" ]]
grep -q '/agent/3asekka-logo.png' "$HTML"
grep -q '📞 اتصل' "$HTML"
grep -q 'ابدأ نقلتك' "$HTML"
grep -q 'renderOffers(data.offers' "$HTML"
echo "PUBLIC_UI=PASS"

echo "[6/7] Full end-to-end API workflow..."
REQ="/tmp/3asekka_req_$STAMP.json"
RESP="/tmp/3asekka_resp_$STAMP.json"
python3 - "$REQ" <<'PY'
import json,sys
with open(sys.argv[1],"w",encoding="utf-8") as f:
    json.dump({"input":"عايز أنقل 20 كرتونة من سموحة للمنشية بكرة الساعة 3، وزنهم حوالي 250 كيلو والمسافة 12 كم"},f,ensure_ascii=True)
PY

API_HTTP="$(curl -k -sS -o "$RESP" -w '%{http_code}'   -H 'content-type: application/json'   --data-binary @"$REQ"   https://3asekka.com/agent/api/agent)"
echo "PUBLIC_API_HTTP=$API_HTTP"
[[ "$API_HTTP" == "200" ]]

python3 - "$RESP" <<'PY'
import json,sys
d=json.load(open(sys.argv[1],encoding="utf-8"))
req=d.get("request") or {}
rec=d.get("recommendation") or {}
route=d.get("route") or {}
pricing=d.get("pricing") or {}
offers=d.get("offers") or []

print("STATUS="+str(d.get("status")))
print("PICKUP="+str(req.get("pickup")))
print("DESTINATION="+str(req.get("destination")))
print("CARGO="+str(req.get("cargo")))
print("WEIGHT="+str(req.get("weightKg")))
print("VEHICLE="+str(rec.get("vehicleNameAr")))
print("DISTANCE="+str(route.get("distanceKm")))
print("FARE="+str(pricing.get("estimatedFare")))
print("OFFERS="+str(len(offers)))

if not req.get("pickup"): raise SystemExit("pickup missing")
if not req.get("destination"): raise SystemExit("destination missing")
if not req.get("cargo"): raise SystemExit("cargo missing")
if req.get("weightKg") is None: raise SystemExit("weight missing")
if not rec.get("vehicleNameAr"): raise SystemExit("vehicle missing")
if route.get("distanceKm") is None: raise SystemExit("distance missing")
if pricing.get("estimatedFare") is None: raise SystemExit("fare missing")
if len(offers) < 3: raise SystemExit("driver offers missing")
print("PUBLIC_WORKFLOW=PASS")
PY

echo "[7/7] Health..."
HEALTH="$(curl -k -sS -o /tmp/3asekka_health_$STAMP.json -w '%{http_code}' https://3asekka.com/agent/health)"
echo "PUBLIC_HEALTH_HTTP=$HEALTH"
[[ "$HEALTH" == "200" ]]

trap - ERR
echo
echo "======================================"
echo "PATCH=PASS"
echo "DEPLOY_OK=YES"
echo "MAIN_SITE_LOGO=YES"
echo "WORKFLOW_COMPLETE=YES"
echo "DRIVER_OFFERS=YES"
echo "FINAL_URL=https://3asekka.com/agent"
echo "======================================"

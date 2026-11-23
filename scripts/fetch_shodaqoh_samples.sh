#!/usr/bin/env bash
# Logs in and saves the answers of the shodaqoh endpoints and of the fundraising
# list, so the app's parsers can be checked against real responses
# (docs/KURBAN_AMAL_JARIYAH_API.md), and prints which campaigns the logged-in
# member has contributed to.
#
#   BARAKA_USER=<user_id> BARAKA_PASS=<password> scripts/fetch_shodaqoh_samples.sh [outdir]
#
# or, with a token you already have:
#   BARAKA_TOKEN=<jwt> scripts/fetch_shodaqoh_samples.sh [outdir]
#
# Output goes to [outdir] (default ./shodaqoh_samples). The files hold personal
# data (names, amounts): review them before sharing, and do not commit them.
set -euo pipefail

BASE="${BARAKA_API:-https://baraka-api.sangkarahub.app}"
OUT="${1:-./shodaqoh_samples}"
mkdir -p "$OUT"

TOKEN="${BARAKA_TOKEN:-}"
if [ -z "$TOKEN" ]; then
  : "${BARAKA_USER:?set BARAKA_USER and BARAKA_PASS, or BARAKA_TOKEN}"
  : "${BARAKA_PASS:?set BARAKA_USER and BARAKA_PASS, or BARAKA_TOKEN}"
  TOKEN=$(curl -sS --max-time 20 -X POST "$BASE/login" \
    -H 'Content-Type: application/json' \
    --data "$(printf '{"user_id":"%s","password":"%s"}' "$BARAKA_USER" "$BARAKA_PASS")" |
    python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("token") or (d.get("data") or {}).get("token") or "")')
  [ -n "$TOKEN" ] || { echo "login failed: no token in the answer" >&2; exit 1; }
fi

MONTH=$(date +%Y-%m)
YEAR=$(date +%Y)
fetch() { # name path
  local code
  code=$(curl -sS --max-time 30 -o "$OUT/$1.json" -w '%{http_code}' \
    -H "Authorization: Bearer $TOKEN" "$BASE/api/m/v1/$2")
  echo "$code  $2  ->  $OUT/$1.json"
}

fetch qurban-savings              "shodaqoh/me/qurban-savings"
fetch family-report               "shodaqoh/me/family-report?period=$MONTH"
fetch family-report-yearly        "shodaqoh/me/family-report-yearly?year=$YEAR"
fetch family-collection-summary   "shodaqoh/me/family-collection-summary?item_code=K-07"
fetch fundraising                 "fundraising"

# Which campaigns does this login show a contribution for?
python3 - "$OUT/fundraising.json" <<'PY'
import json, sys
try:
    body = json.load(open(sys.argv[1]))
except Exception as e:
    print(f"\nfundraising: not JSON ({e})"); sys.exit(0)
if "error" in body:
    print("\nfundraising: error from server:", body["error"]); sys.exit(0)
body = body.get("data", body) if isinstance(body.get("data"), dict) else body
print("\ncontribution_available:", body.get("contribution_available"))
for c in body.get("campaigns") or []:
    k = c.get("contribution")
    print("-", c.get("title") or c.get("name"), "|",
          "no contribution (null)" if k is None
          else f"given {k.get('total_given')} in {k.get('payment_count')} payment(s), last {k.get('last_paid_date')}")
PY

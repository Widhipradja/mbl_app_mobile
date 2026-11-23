#!/usr/bin/env bash
# Builds the release APK and publishes it to the update host
# (https://apk.sangkarahub.app), where the app's own update check finds it.
#
#   export UPLOAD_TOKEN=<UPLOAD_TOKEN of the host's .env>
#   scripts/publish_apk.sh [options]
#
# Options:
#   --code N          versionCode (default: the host's newest + 1)
#   --name TEXT       versionName shown to users (default: 1.0.<code>)
#   --notes TEXT      release notes shown in the update dialog
#   --min-code N      installs older than N must update (forced update)
#   --dry-run         build and check the APK, but do not upload
#   --yes             upload without asking
#   --next            only print the versionCode that would be used
#   --verify-apk FILE only check FILE (signature, size), no build, no upload
#
# The token is read from the environment and never written anywhere. The
# upload is asked about first: it is public as soon as it is up.
set -euo pipefail

HOST="${APK_HOST:-https://apk.sangkarahub.app}"
PACKAGE="com.baraka.app"

# SHA-256 of the release certificate the published builds are signed with
# (CN=Baraka, O=Desalabs). A fingerprint is public. An APK signed with any
# other key would be refused by Android as an update, so it is never uploaded.
# Override with RELEASE_CERT_SHA256 only if the signing key is replaced.
EXPECTED_CERT="${RELEASE_CERT_SHA256:-c0591e5acf784def9f0f0a345e2650edb551319681ce522a83eb151a138ea0fc}"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CODE="" NAME="" NOTES="" MIN_CODE="" DRY=0 YES=0 NEXT=0 VERIFY=""

die() { echo "error: $*" >&2; exit 1; }

while [ $# -gt 0 ]; do
  case "$1" in
    --code) CODE="${2:?--code needs a number}"; shift 2 ;;
    --name) NAME="${2:?--name needs a text}"; shift 2 ;;
    --notes) NOTES="${2:?--notes needs a text}"; shift 2 ;;
    --min-code) MIN_CODE="${2:?--min-code needs a number}"; shift 2 ;;
    --dry-run) DRY=1; shift ;;
    --yes) YES=1; shift ;;
    --next) NEXT=1; shift ;;
    --verify-apk) VERIFY="${2:?--verify-apk needs a file}"; shift 2 ;;
    -h|--help) sed -n '2,22p' "$0"; exit 0 ;;
    *) die "unknown option: $1 (see --help)" ;;
  esac
done

for n in CODE MIN_CODE; do
  v="${!n}"
  [ -z "$v" ] || [[ "$v" =~ ^[0-9]+$ ]] || die "$n must be a whole number, got '$v'"
done

# ── The host ────────────────────────────────────────────────────────────────

INDEX_JSON=""
fetch_index() {
  [ -n "$INDEX_JSON" ] && return 0
  INDEX_JSON="$(curl -fsS --max-time 20 -H 'Cache-Control: no-cache' "$HOST/index.json")" ||
    die "cannot read $HOST/index.json"
}

# newest versionCode of $PACKAGE on the host (0 when none), and its name
index_field() { # newest_code | app_name
  fetch_index
  PKG="$PACKAGE" FIELD="$1" python3 -c '
import json, os, sys
m = json.load(sys.stdin)
for a in m.get("apps", []):
    if a.get("package") == os.environ["PKG"]:
        v = a.get("versions", [])
        if os.environ["FIELD"] == "newest_code":
            print(max([x.get("versionCode", 0) for x in v] or [0]))
        else:
            print(a.get("name") or os.environ["PKG"])
        sys.exit(0)
print(0 if os.environ["FIELD"] == "newest_code" else os.environ["PKG"])
' <<<"$INDEX_JSON"
}

if [ "$NEXT" = 1 ]; then
  echo $(( $(index_field newest_code) + 1 ))
  exit 0
fi

# ── Checking an APK ─────────────────────────────────────────────────────────

find_apksigner() {
  command -v apksigner 2>/dev/null && return 0
  local sdk="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-$HOME/Library/Android/sdk}}"
  ls "$sdk"/build-tools/*/apksigner 2>/dev/null | sort -V | tail -1
}

# Fails unless the APK is validly signed with the release certificate.
verify_apk() { # file
  local apk="$1" signer out sha dn
  [ -f "$apk" ] || die "no such file: $apk"
  signer="$(find_apksigner)"
  [ -n "$signer" ] || die "apksigner not found (install Android build-tools or set ANDROID_HOME)"
  out="$("$signer" verify --print-certs "$apk" 2>&1)" ||
    die "apksigner could not verify $apk:
$out"
  sha="$(sed -n 's/^Signer #1 certificate SHA-256 digest: //p' <<<"$out" | head -1 | tr 'A-F' 'a-f')"
  dn="$(sed -n 's/^Signer #1 certificate DN: //p' <<<"$out" | head -1)"
  [ -n "$sha" ] || die "no signing certificate found in $apk"
  echo "signed by:   $dn"
  echo "certificate: $sha"
  case "$dn" in
    *"Android Debug"*) die "$apk is signed with the DEBUG key. Check android/key.properties." ;;
  esac
  [ "$sha" = "$EXPECTED_CERT" ] ||
    die "the certificate is not the release one ($EXPECTED_CERT).
Android would refuse this APK as an update of the installed app."
  echo "signature:   matches the published builds"
}

if [ -n "$VERIFY" ]; then
  verify_apk "$VERIFY"
  echo "size:        $(wc -c <"$VERIFY" | tr -d ' ') bytes"
  exit 0
fi

# ── Build ───────────────────────────────────────────────────────────────────

[ "$DRY" = 1 ] || [ -n "${UPLOAD_TOKEN:-}" ] ||
  die "set UPLOAD_TOKEN (the host's upload token), or use --dry-run"

NEWEST="$(index_field newest_code)"
[ -n "$CODE" ] || CODE=$(( NEWEST + 1 ))
[ "$CODE" -gt "$NEWEST" ] ||
  die "versionCode $CODE is not above the host's newest ($NEWEST): the update would not be offered"
[ -n "$NAME" ] || NAME="1.0.$CODE"
[ -z "$MIN_CODE" ] || [ "$MIN_CODE" -le "$CODE" ] ||
  die "--min-code $MIN_CODE is above the new versionCode $CODE"
APP_NAME="$(index_field app_name)"

[ -f "$ROOT/android/key.properties" ] ||
  die "android/key.properties is missing: the build would be signed with the debug key"

cd "$ROOT"
if [ -n "$(git status --porcelain 2>/dev/null | grep -v '^??' || true)" ]; then
  echo "note: the working tree has uncommitted changes; they go into this build." >&2
fi

echo "publishing $PACKAGE  versionCode $CODE  versionName \"$NAME\"  (host newest: $NEWEST)"
OUT_DIR="$ROOT/build/app/outputs"
START_MARK="$(mktemp)"
trap 'rm -f "$START_MARK"' EXIT

flutter build apk --release --build-name "$NAME" --build-number "$CODE"

# The Gradle config renames the APK, so take the newest one this build made.
APK="$(find "$OUT_DIR" -name '*.apk' -newer "$START_MARK" 2>/dev/null |
  xargs ls -t 2>/dev/null | head -1)"
[ -n "$APK" ] && [ -f "$APK" ] || die "the build finished but no APK was found under $OUT_DIR"
echo "built: $APK"

verify_apk "$APK"
SHA="$(shasum -a 256 "$APK" | cut -d' ' -f1)"
SIZE="$(wc -c <"$APK" | tr -d ' ')"
echo "sha256:      $SHA"
echo "size:        $SIZE bytes"

if [ "$DRY" = 1 ]; then
  echo "dry run: not uploaded."
  exit 0
fi

# ── Upload ──────────────────────────────────────────────────────────────────

if [ "$YES" != 1 ]; then
  printf 'Upload %s %s (%s) to %s? [y/N] ' "$PACKAGE" "$NAME" "$CODE" "$HOST"
  read -r answer
  case "$answer" in y|Y|yes|YES) ;; *) echo "cancelled."; exit 1 ;; esac
fi

QUERY="$(PKG="$PACKAGE" APP="$APP_NAME" CODE="$CODE" NAME="$NAME" NOTES="$NOTES" MINC="$MIN_CODE" python3 -c '
import os, urllib.parse
q = {"package": os.environ["PKG"], "name": os.environ["APP"],
     "versionCode": os.environ["CODE"], "versionName": os.environ["NAME"],
     "notes": os.environ["NOTES"]}
if os.environ["MINC"]:
    q["minVersionCode"] = os.environ["MINC"]
print(urllib.parse.urlencode(q))
')"

BODY="$(mktemp)"
trap 'rm -f "$START_MARK" "$BODY"' EXIT
STATUS="$(curl -sS --progress-bar --max-time 900 -o "$BODY" -w '%{http_code}' \
  -H "Authorization: Bearer $UPLOAD_TOKEN" \
  --data-binary @"$APK" "$HOST/upload?$QUERY")" || die "the upload did not complete"
echo
[ "$STATUS" -ge 200 ] && [ "$STATUS" -lt 300 ] ||
  die "the host refused the upload (HTTP $STATUS): $(head -c 400 "$BODY")"

# ── Check it is listed ─────────────────────────────────────────────────────

INDEX_JSON=""
fetch_index
PKG="$PACKAGE" CODE="$CODE" SHA="$SHA" python3 -c '
import json, os, sys
m = json.load(sys.stdin)
for a in m.get("apps", []):
    if a.get("package") == os.environ["PKG"]:
        for v in a.get("versions", []):
            if str(v.get("versionCode")) == os.environ["CODE"]:
                ok = v.get("sha256") == os.environ["SHA"]
                print("listed on the host, sha256 " + ("matches" if ok else "DIFFERS"))
                sys.exit(0 if ok else 2)
print("not listed yet")
sys.exit(3)
' <<<"$INDEX_JSON" || die "the upload answered OK but the host's index does not show it correctly"

echo "published: $HOST/  ->  $PACKAGE $NAME ($CODE)"

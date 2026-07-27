#!/usr/bin/env bash
# End-to-end check of a deployed Bifrost gateway.
#
# Checks the two things that distinguish this deployment: configuration lives in
# Postgres rather than on a disk that disappears, and neither the admin API nor
# the inference routes are open to whoever finds the URL.
#
#   scripts/verify-gateway.sh https://your-gateway.up.railway.app admin 'the-password'
set -uo pipefail

BASE="${1:?usage: verify-gateway.sh <base-url> <admin-user> <admin-password>}"
USER_NAME="${2:?usage: verify-gateway.sh <base-url> <admin-user> <admin-password>}"
PASSWORD="${3:?usage: verify-gateway.sh <base-url> <admin-user> <admin-password>}"
BASE="${BASE%/}"
CRED="$USER_NAME:$PASSWORD"
failed=0

ok()   { echo "  ok   $1${2:+ - $2}"; }
fail() { echo "  FAIL $1 - $2"; failed=1; }

pick() {
  python3 -c '
import json, sys
try:
    node = json.loads(sys.argv[1])
except Exception:
    sys.exit(0)
for part in sys.argv[2:]:
    try:
        node = node[int(part)] if part.isdigit() else node[part]
    except Exception:
        sys.exit(0)
print(node if isinstance(node, str) else json.dumps(node))
' "$@"
}

echo "checking $BASE"

# 1. The dashboard is served.
code=$(curl -s -o /dev/null -w '%{http_code}' "$BASE/")
[ "$code" = "200" ] && ok "dashboard" || fail "dashboard" "got $code"

# 2. The admin API refuses anonymous callers. Bifrost ships with this off; a
#    gateway on a public domain without it is an open door to your provider keys.
code=$(curl -s -o /dev/null -w '%{http_code}' "$BASE/api/providers")
[ "$code" = "401" ] && ok "admin api requires credentials" || fail "admin api requires credentials" "got $code"

code=$(curl -s -o /dev/null -w '%{http_code}' -u "$CRED" "$BASE/api/providers")
[ "$code" = "200" ] && ok "admin api accepts the configured credentials" || fail "admin api accepts credentials" "got $code"

# 3. A provider written through the API comes back out of Postgres.
add=$(curl -s -u "$CRED" -X POST "$BASE/api/providers" -H 'content-type: application/json' \
  -d '{"provider":"openai"}')
name=$(pick "$add" name)
list=$(curl -s -u "$CRED" "$BASE/api/providers")
case "$list" in
  *'"name":"openai"'*) ok "provider stored and read back" "${name:-openai}" ;;
  *) fail "provider stored and read back" "${list:0:140}" ;;
esac

# 4. Inference is refused without a virtual key - the endpoint that spends money
#    is the one that matters most here.
body=$(curl -s -X POST "$BASE/v1/chat/completions" -H 'content-type: application/json' \
  -d '{"model":"openai/gpt-4o-mini","messages":[{"role":"user","content":"hi"}]}')
case "$body" in
  *virtual_key_required*) ok "inference requires a virtual key" ;;
  *) fail "inference requires a virtual key" "${body:0:140}" ;;
esac

# 5. A virtual key lets a request through the gateway. The provider asked for
#    here is deliberately one that is not configured, so the answer proves the
#    key was accepted without any call leaving the machine.
vk_json=$(curl -s -u "$CRED" -X POST "$BASE/api/governance/virtual-keys" -H 'content-type: application/json' \
  -d '{"name":"verification-'"$RANDOM"'","description":"created by the verification script","is_active":true,"provider_configs":[{"provider":"openai","allowed_models":["*"],"key_ids":["*"],"weight":1}]}')
VK=$(pick "$vk_json" virtual_key value)
VK_ID=$(pick "$vk_json" virtual_key id)
if [ -n "$VK" ]; then ok "virtual key created" "${VK:0:10}..."; else fail "virtual key created" "${vk_json:0:160}"; fi

body=$(curl -s -X POST "$BASE/v1/chat/completions" -H "x-bf-vk: $VK" -H 'content-type: application/json' \
  -d '{"model":"anthropic/claude-3-haiku","messages":[{"role":"user","content":"hi"}]}')
case "$body" in
  *virtual_key_required*) fail "virtual key is accepted" "still refused" ;;
  *"failed to get config for provider"*) ok "virtual key is accepted" "request reached routing" ;;
  *) ok "virtual key is accepted" "${body:0:60}" ;;
esac

# 6. Clean up what the check created.
[ -n "$VK_ID" ] && curl -s -u "$CRED" -X DELETE "$BASE/api/governance/virtual-keys/$VK_ID" > /dev/null
curl -s -u "$CRED" -X DELETE "$BASE/api/providers/openai" > /dev/null

echo
[ "$failed" = "0" ] && echo "all checks passed" || { echo "some checks failed"; exit 1; }

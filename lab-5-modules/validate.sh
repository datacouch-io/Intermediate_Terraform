#!/usr/bin/env bash
# Lab 5 validation. Run from lab-5-modules/. Checks BOTH workspaces.
#
# Portability note: written for bash 3.2, which is what macOS ships. No
# associative arrays (`declare -A`) -- they are bash 4+ and fail on macOS with
# a confusing "unbound variable" error under `set -u`.
set -uo pipefail
fail=0
check() { if [ "$2" = "$3" ]; then echo "PASS  $1"; else echo "FAIL  $1 (got '$2', want '$3')"; fail=1; fi }

want_type()  { case "$1" in dev) echo t3.micro;;      prod) echo t3.small;;      esac; }
want_count() { case "$1" in dev) echo 1;;             prod) echo 2;;             esac; }
want_cidr()  { case "$1" in dev) echo 10.51.0.0/16;;  prod) echo 10.52.0.0/16;;  esac; }

ORIG=$(terraform workspace show)
DEV_IDS=""; PROD_IDS=""

check "dev and prod workspaces both exist" \
  "$(terraform workspace list | grep -cE '^\*? *(dev|prod)$')" "2"

check "each workspace has an isolated state file" \
  "$(find terraform.tfstate.d -name '*.tfstate' | wc -l | tr -d ' ')" "2"

for ws in dev prod; do
  terraform workspace select "$ws" >/dev/null 2>&1

  check "[$ws] instance_count from the workspace map" \
    "$(terraform output -json instance_ids | python3 -c 'import json,sys;print(len(json.load(sys.stdin)))')" \
    "$(want_count "$ws")"

  check "[$ws] instance_type from the workspace map" \
    "$(terraform output -json settings_used | python3 -c 'import json,sys;print(json.load(sys.stdin)["instance_type"])')" \
    "$(want_type "$ws")"

  check "[$ws] VPC CIDR from the workspace map" \
    "$(aws ec2 describe-vpcs --vpc-ids "$(terraform output -raw vpc_id)" --query 'Vpcs[0].CidrBlock' --output text)" \
    "$(want_cidr "$ws")"

  for url in $(terraform output -json urls | python3 -c 'import json,sys;[print(u) for u in json.load(sys.stdin)]'); do
    check "[$ws] HTTP 200 from $url" \
      "$(curl -s -o /dev/null -w '%{http_code}' --max-time 15 "$url")" "200"
    check "[$ws] page reports its own environment" \
      "$(curl -sS --max-time 15 "$url" | sed -n 's/.*<span class="env">\([a-z]*\)<\/span>.*/\1/p')" "$ws"
  done

  ids=$(terraform output -json instance_ids | python3 -c 'import json,sys;print(" ".join(sorted(json.load(sys.stdin))))')
  if [ "$ws" = "dev" ]; then DEV_IDS="$ids"; else PROD_IDS="$ids"; fi
done

# THE ONE THE HAPPY PATH MISSES: are the two environments genuinely SEPARATE?
# Every check above would still pass if both workspaces pointed at the same
# instances -- which is what happens when a module is parameterised but a
# resource name is not made workspace-unique.
OVERLAP=$(python3 -c "
import sys
d=set('''$DEV_IDS'''.split()); p=set('''$PROD_IDS'''.split())
print(len(d & p))
")
check "dev and prod share ZERO instances" "$OVERLAP" "0"

terraform workspace select "$ORIG" >/dev/null 2>&1
echo
[ $fail -eq 0 ] && echo "Lab 5 validation: ALL CHECKS PASSED" || echo "Lab 5 validation: FAILURES ABOVE"
exit $fail

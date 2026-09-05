#!/usr/bin/env bash
# Lab 6 validation. Run after you have fixed all four errors and applied.
set -uo pipefail
fail=0
check() { if [ "$2" = "$3" ]; then echo "PASS  $1"; else echo "FAIL  $1 (got '$2', want '$3')"; fail=1; fi }

# 1. The configuration parses and type-checks.
terraform validate -no-color >/dev/null 2>&1
check "terraform validate succeeds" "$?" "0"

# 2. It is also formatted (a different check entirely -- fmt is not validate).
terraform fmt -check -recursive >/dev/null 2>&1
check "terraform fmt reports no changes needed" "$?" "0"

# 3. The app instance exists and is running.
ID=$(terraform output -raw app_id)
check "app instance is running" \
  "$(aws ec2 describe-instances --instance-ids "$ID" --query 'Reservations[0].Instances[0].State.Name' --output text)" \
  "running"

# 4. The AMI came from the data source, not a hardcoded string. This is the
#    regression check for the actual bug: a literal ami- id in any .tf file.
check "no hardcoded ami- literal remains in any .tf file" \
  "$(grep -oE '"ami-[0-9a-f]+"' ./*.tf 2>/dev/null | wc -l | tr -d ' ')" "0"

check "running AMI matches what the data source resolves now" \
  "$(aws ec2 describe-instances --instance-ids "$ID" --query 'Reservations[0].Instances[0].ImageId' --output text)" \
  "$(aws ec2 describe-images --owners amazon \
      --filters 'Name=name,Values=al2023-ami-2023.*-kernel-6.1-x86_64' 'Name=state,Values=available' \
      --query 'sort_by(Images,&CreationDate)[-1].ImageId' --output text)"

# 5. The conditional output resolves with the bastion DISABLED. `one()` returns
#    null here; an aws_instance.bastion[0] reference would hard-error instead.
terraform plan -no-color -var enable_bastion=false >/dev/null 2>&1
check "plan succeeds with the conditional resource DISABLED" "$?" "0"

# 6. ...and with it ENABLED. Both directions must work, which is the whole point
#    of the count-based conditional.
terraform plan -no-color -var enable_bastion=true >/dev/null 2>&1
check "plan succeeds with the conditional resource ENABLED" "$?" "0"

# 7. THE ONE THE HAPPY PATH MISSES: `terraform validate` passing does NOT mean
#    a plan will succeed. validate never evaluates variable values, so an
#    out-of-range index like aws_instance.bastion[0] passes validate and fails
#    at plan. Assert the stronger property explicitly.
out=$(terraform plan -no-color -var enable_bastion=false 2>&1)
if printf '%s' "$out" | grep -q 'Error:'; then
  echo "FAIL  plan emits no errors (validate passing is not enough)"; fail=1
else
  echo "PASS  plan emits no errors (validate passing is not enough)"
fi

echo
[ $fail -eq 0 ] && echo "Lab 6 validation: ALL CHECKS PASSED" || echo "Lab 6 validation: FAILURES ABOVE"
exit $fail

#!/usr/bin/env bash
# Lab 2 validation. Run from lab-2-variables/ after `terraform apply`.
set -uo pipefail
fail=0
check() { if [ "$2" = "$3" ]; then echo "PASS  $1"; else echo "FAIL  $1 (got '$2', want '$3')"; fail=1; fi }

PREFIX=$(terraform output -raw name_prefix)
ID=$(terraform output -json instance | python3 -c 'import json,sys;print(json.load(sys.stdin)["id"])')
IP=$(terraform output -json instance | python3 -c 'import json,sys;print(json.load(sys.stdin)["public_ip"])')
TYPE=$(terraform output -json instance | python3 -c 'import json,sys;print(json.load(sys.stdin)["instance_type"])')
AMI=$(terraform output -json resolved_ami | python3 -c 'import json,sys;print(json.load(sys.stdin)["id"])')

# 1. The local computed the naming convention from the two variables in tfvars,
#    rather than being a literal string someone typed.
WANT_PREFIX="$(grep '^project_name' terraform.tfvars | cut -d'"' -f2)-$(grep '^environment' terraform.tfvars | cut -d'"' -f2)"
check "name_prefix is computed from two variables" "$PREFIX" "$WANT_PREFIX"

# 2. That computed name actually reached AWS as a tag.
check "Name tag on the real instance matches the local" \
  "$(aws ec2 describe-instances --instance-ids "$ID" --query "Reservations[0].Instances[0].Tags[?Key=='Name']|[0].Value" --output text)" \
  "${PREFIX}-app"

# 3. common_tags were merged, not overwritten by the per-resource Name tag.
check "merge() kept ManagedBy from common_tags" \
  "$(aws ec2 describe-instances --instance-ids "$ID" --query "Reservations[0].Instances[0].Tags[?Key=='ManagedBy']|[0].Value" --output text)" \
  "terraform"

# 4. The instance really is running the AMI the data source chose.
check "instance AMI == data source AMI (nothing hardcoded)" \
  "$(aws ec2 describe-instances --instance-ids "$ID" --query 'Reservations[0].Instances[0].ImageId' --output text)" \
  "$AMI"

# 5. The provisioner produced its file.
if [ -f deployment.txt ]; then echo "PASS  local-exec wrote deployment.txt"; else echo "FAIL  deployment.txt missing"; fail=1; fi

# 6. THE ONE THE HAPPY PATH MISSES: is deployment.txt actually CURRENT?
#    The file existing proves the provisioner ran once, at some point. It does not
#    prove it re-ran after the last change. A stale artifact here is the classic
#    provisioner bug: triggers that do not cover everything that can change.
FILE_IP=$(grep '^public_ip=' deployment.txt | cut -d= -f2)
FILE_TYPE=$(grep '^instance_type=' deployment.txt | cut -d= -f2)
check "deployment.txt IP is current, not stale" "$FILE_IP" "$IP"
check "deployment.txt instance_type is current, not stale" "$FILE_TYPE" "$TYPE"
FILE_NAME=$(grep '^name=' deployment.txt | cut -d= -f2)
check "deployment.txt name is current, not stale" "$FILE_NAME" "${PREFIX}-app"

# 7. Config and reality agree.
terraform plan -detailed-exitcode -no-color > /dev/null 2>&1
case $? in
  0) echo "PASS  no drift: plan reports zero changes" ;;
  2) echo "FAIL  DRIFT: plan wants to change something"; fail=1 ;;
  *) echo "FAIL  plan errored"; fail=1 ;;
esac

echo
[ $fail -eq 0 ] && echo "Lab 2 validation: ALL CHECKS PASSED" || echo "Lab 2 validation: FAILURES ABOVE"
exit $fail

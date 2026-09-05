#!/usr/bin/env bash
# Lab 1 validation. Run from the lab-1-first-project directory after `terraform apply`.
set -uo pipefail
fail=0
check() { if [ "$2" = "$3" ]; then echo "PASS  $1"; else echo "FAIL  $1 (got '$2', want '$3')"; fail=1; fi }

ID=$(terraform output -raw instance_id 2>/dev/null)
IP=$(terraform output -raw instance_public_ip 2>/dev/null)

# 1. Terraform believes it manages exactly one resource.
check "state holds exactly 1 resource" "$(terraform state list | wc -l | tr -d ' ')" "1"

# 2. That resource is the instance we named.
check "the managed resource is aws_instance.lab" "$(terraform state list)" "aws_instance.lab"

# 3. AWS agrees the instance exists and is running.
check "AWS reports the instance running" \
  "$(aws ec2 describe-instances --instance-ids "$ID" --query 'Reservations[0].Instances[0].State.Name' --output text)" \
  "running"

# 4. The tag AWS holds matches the tag we declared.
check "Name tag round-tripped to AWS" \
  "$(aws ec2 describe-instances --instance-ids "$ID" --query "Reservations[0].Instances[0].Tags[?Key=='Name']|[0].Value" --output text)" \
  "tf-lab1-first-instance"

# 5. The output is a routable public IPv4, not empty and not a private range.
if [[ "$IP" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] && [[ ! "$IP" =~ ^(10\.|172\.(1[6-9]|2[0-9]|3[01])\.|192\.168\.) ]]; then
  echo "PASS  public IP is a routable IPv4 ($IP)"
else
  echo "FAIL  public IP looks wrong: '$IP'"; fail=1
fi

# 6. THE ONE THE HAPPY PATH MISSES: config and reality still agree.
#    A successful apply does not prove this stays true — anything that changed the
#    instance afterwards (a console edit, a half-failed apply) shows up here as
#    exit code 2 while every check above still passes.
terraform plan -detailed-exitcode -no-color > /dev/null 2>&1
case $? in
  0) echo "PASS  no drift: plan reports zero changes" ;;
  2) echo "FAIL  DRIFT: plan wants to change something — run 'terraform plan' to see what"; fail=1 ;;
  *) echo "FAIL  plan errored"; fail=1 ;;
esac

echo
[ $fail -eq 0 ] && echo "Lab 1 validation: ALL CHECKS PASSED" || echo "Lab 1 validation: FAILURES ABOVE"
exit $fail

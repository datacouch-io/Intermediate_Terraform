#!/usr/bin/env bash
# Lab 4 validation. Run from lab-4-mini-app/ after `terraform apply`.
set -uo pipefail
fail=0
check() { if [ "$2" = "$3" ]; then echo "PASS  $1"; else echo "FAIL  $1 (got '$2', want '$3')"; fail=1; fi }

URL=$(terraform output -raw web_url)
ID=$(terraform output -raw instance_id)
VPC=$(terraform output -raw vpc_id)

# 1. The site answers at all.
check "HTTP 200 from $URL" \
  "$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "$URL")" "200"

# 2. nginx is actually the thing answering, not an ELB or an error page.
check "served by nginx" \
  "$(curl -sI --max-time 10 "$URL" | awk -F'/' '/^Server:/{print tolower($1)}' | tr -d ' \r' | sed 's/server://')" \
  "nginx"

# 3. The instance lives in OUR VPC, not the account's default one.
check "instance is in the purpose-built VPC" \
  "$(aws ec2 describe-instances --instance-ids "$ID" --query 'Reservations[0].Instances[0].VpcId' --output text)" \
  "$VPC"

# 4. cidrsubnet() computed the subnet we expect from the /16.
check "subnet CIDR computed by cidrsubnet()" "$(terraform output -raw subnet_cidr)" "10.20.1.0/24"

# 5. The route table has a default route to the internet gateway. This -- not
#    map_public_ip_on_launch -- is what makes the subnet public.
check "default route points at an internet gateway" \
  "$(aws ec2 describe-route-tables --filters Name=vpc-id,Values="$VPC" \
      --query "RouteTables[0].Routes[?DestinationCidrBlock=='0.0.0.0/0'].GatewayId | [0]" --output text | cut -c1-4)" \
  "igw-"

# 6. Nothing opened SSH by accident.
check "port 22 is NOT open" \
  "$(aws ec2 describe-security-group-rules \
      --filters Name=group-id,Values="$(aws ec2 describe-instances --instance-ids "$ID" \
        --query 'Reservations[0].Instances[0].SecurityGroups[0].GroupId' --output text)" \
      --query "length(SecurityGroupRules[?FromPort==\`22\`])" --output text)" \
  "0"

# 7. THE ONE THE HAPPY PATH MISSES: is THIS instance serving the page?
#    A 200 only proves *something* answered on that IP. If the output were stale,
#    or an old instance still held the address, checks 1-2 would still pass while
#    you looked at infrastructure you no longer manage.
PAGE_ID=$(curl -sS --max-time 10 "$URL" | sed -n 's/.*<dt>Instance ID<\/dt><dd>\(i-[0-9a-f]*\)<\/dd>.*/\1/p')
check "the page is served BY the managed instance" "$PAGE_ID" "$ID"

echo
[ $fail -eq 0 ] && echo "Lab 4 validation: ALL CHECKS PASSED" || echo "Lab 4 validation: FAILURES ABOVE"
exit $fail

#!/usr/bin/env bash
# Lab 7 validation. Run from lab-7-functions/ after `terraform apply`.
set -uo pipefail
fail=0
check() { if [ "$2" = "$3" ]; then echo "PASS  $1"; else echo "FAIL  $1 (got '$2', want '$3')"; fail=1; fi }

# 1. length() drove the number of resources actually created.
check "one instance per element of var.environments" \
  "$(terraform state list | grep -c '^aws_instance.env\[')" "3"

# 2-4. Each generated name reached AWS exactly as join() computed it.
for env in dev staging prod; do
  check "[$env] Name tag == join(\"-\", [project, env])" \
    "$(aws ec2 describe-instances --filters Name=tag:Env,Values=$env Name=instance-state-name,Values=running \
        --query "Reservations[0].Instances[0].Tags[?Key=='Name']|[0].Value" --output text)" \
    "tflab7-$env"
done

# 5. lookup() with a fallback: prod hits the map, dev misses it.
check "prod got t3.small from size_map" \
  "$(aws ec2 describe-instances --filters Name=tag:Env,Values=prod Name=instance-state-name,Values=running \
      --query 'Reservations[0].Instances[0].InstanceType' --output text)" "t3.small"
check "dev fell back to the lookup() default" \
  "$(aws ec2 describe-instances --filters Name=tag:Env,Values=dev Name=instance-state-name,Values=running \
      --query 'Reservations[0].Instances[0].InstanceType' --output text)" "t3.micro"

# 6. split() + trimspace() actually cleaned the messy CSV input. The source
#    string has leading/trailing spaces around every element.
OWNERS=$(aws ec2 describe-instances --filters Name=tag:Env,Values=dev Name=instance-state-name,Values=running \
  --query "Reservations[0].Instances[0].Tags[?Key=='Owners']|[0].Value" --output text)
check "trimspace() removed all whitespace from the owner list" "$OWNERS" \
  "platform@example.com;sre@example.com;data@example.com"

# 7. length() reached AWS as a tag, computed not typed.
check "EnvCount tag equals length(var.environments)" \
  "$(aws ec2 describe-instances --filters Name=tag:Env,Values=dev Name=instance-state-name,Values=running \
      --query "Reservations[0].Instances[0].Tags[?Key=='EnvCount']|[0].Value" --output text)" "3"

# 8. No environment name is a literal in any resource body. This is the
#    regression guard for the lab's actual claim.
check "no env name is hardcoded outside variables.tf" \
  "$(grep -E '"(dev|staging|prod)"' main.tf locals.tf outputs.tf 2>/dev/null | wc -l | tr -d ' ')" "0"

# 9. THE ONE THE HAPPY PATH MISSES: are the resources addressed by KEY or by
#    INDEX? A count-based config produces byte-identical AWS resources with
#    byte-identical tags -- every check above would still pass -- but removing
#    an element from the middle of the list then renumbers and rebuilds the
#    survivors. Only the state ADDRESS reveals which style was used.
IDX=$(terraform state list | grep -c '^aws_instance.env\[[0-9]')
check "resources are keyed by name, not by numeric index" "$IDX" "0"

echo
[ $fail -eq 0 ] && echo "Lab 7 validation: ALL CHECKS PASSED" || echo "Lab 7 validation: FAILURES ABOVE"
exit $fail

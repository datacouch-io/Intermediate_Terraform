#!/usr/bin/env bash
# Lab 3 validation. Run from lab-3-state-drift/ after the import step.
set -uo pipefail
fail=0
check() { if [ "$2" = "$3" ]; then echo "PASS  $1"; else echo "FAIL  $1 (got '$2', want '$3')"; fail=1; fi }

ID=$(terraform output -raw managed_instance_id)
SG=$(terraform state show -no-color aws_security_group.imported | awk '/^ +id +=/{gsub(/"/,"",$3); print $3; exit}')

# 1. Both the originally-managed and the imported resource are in state.
check "state tracks 3 objects (data + instance + imported sg)" \
  "$(terraform state list | wc -l | tr -d ' ')" "3"

# 2. The imported SG is in state under the address we chose.
check "imported SG is at aws_security_group.imported" \
  "$(terraform state list | grep -c '^aws_security_group.imported$')" "1"

# 3. Drift on the tag was reverted: AWS agrees with the config again.
check "Name tag reverted to the configured value" \
  "$(aws ec2 describe-instances --instance-ids "$ID" --query "Reservations[0].Instances[0].Tags[?Key=='Name']|[0].Value" --output text)" \
  "tf-lab3-managed"

# 4. Drift on a non-tag attribute was reverted too.
check "detailed monitoring reverted to disabled" \
  "$(aws ec2 describe-instances --instance-ids "$ID" --query 'Reservations[0].Instances[0].Monitoring.State' --output text)" \
  "disabled"

# 5. The out-of-band tag Terraform never knew about is gone.
check "untracked CostCentre tag was removed by apply" \
  "$(aws ec2 describe-instances --instance-ids "$ID" --query "length(Reservations[0].Instances[0].Tags[?Key=='CostCentre'])" --output text)" \
  "0"

# 6. The state's recorded ID is the real AWS ID, not a placeholder.
check "state holds the real SG id" \
  "$(aws ec2 describe-security-groups --group-ids "$SG" --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null)" \
  "$SG"

# 7. THE ONE THE HAPPY PATH MISSES: was the import COMPLETE, or only partial?
#    `terraform state list` shows an imported resource whether or not the config
#    that describes it actually matches AWS. A config missing an ingress rule --
#    or carrying a wrong one -- imports perfectly happily and then silently
#    proposes to change real infrastructure on the next apply.
terraform plan -detailed-exitcode -no-color > /dev/null 2>&1
case $? in
  0) echo "PASS  import was COMPLETE: plan proposes no changes" ;;
  2) echo "FAIL  import was PARTIAL: plan wants to alter the imported resource"; fail=1 ;;
  *) echo "FAIL  plan errored"; fail=1 ;;
esac

echo
[ $fail -eq 0 ] && echo "Lab 3 validation: ALL CHECKS PASSED" || echo "Lab 3 validation: FAILURES ABOVE"
exit $fail

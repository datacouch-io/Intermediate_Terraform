#!/usr/bin/env bash
# Lab 8 validation. Run from lab-8-loops-backends/fleet/ after migrating to S3.
set -uo pipefail
fail=0
check() { if [ "$2" = "$3" ]; then echo "PASS  $1"; else echo "FAIL  $1 (got '$2', want '$3')"; fail=1; fi }

BUCKET=$(grep -E '^\s*bucket' backend.tf | head -1 | cut -d'"' -f2)
KEY=$(grep -E '^\s*key' backend.tf | head -1 | cut -d'"' -f2)
N=$(terraform output -raw fleet_size)

# 1. The loop produced the number of instances the variable asked for.
check "state holds fleet_size instances" \
  "$(terraform state list | grep -c '^aws_instance.fleet\[')" "$N"

# 2. AWS agrees, and they are all running.
check "AWS reports $N running fleet instances" \
  "$(aws ec2 describe-instances --filters Name=tag:Lab,Values=8 Name=instance-state-name,Values=running \
      --query 'length(Reservations[].Instances[])' --output text)" "$N"

# 3. format() zero-padded the names: node-01, not node-1.
check "format() produced zero-padded names" \
  "$(terraform output -json node_names | python3 -c 'import json,sys;print(json.load(sys.stdin)[0])')" \
  "tflab8-node-01"

# 4. The state object exists in S3.
check "state object exists in S3" \
  "$(aws s3api head-object --bucket "$BUCKET" --key "$KEY" --query 'ContentLength' --output text >/dev/null 2>&1; echo $?)" "0"

# 5. ...and it is encrypted at rest.
check "S3 state object is encrypted" \
  "$(aws s3api head-object --bucket "$BUCKET" --key "$KEY" --query 'ServerSideEncryption' --output text)" "AES256"

# 6. Versioning is on -- the recovery mechanism for a corrupted state.
check "bucket versioning is enabled" \
  "$(aws s3api get-bucket-versioning --bucket "$BUCKET" --query 'Status' --output text)" "Enabled"

# 7. The bucket is not public. State is plaintext infrastructure detail.
check "bucket blocks all public access" \
  "$(aws s3api get-public-access-block --bucket "$BUCKET" \
      --query 'PublicAccessBlockConfiguration.[BlockPublicAcls,BlockPublicPolicy,IgnorePublicAcls,RestrictPublicBuckets]' \
      --output text | tr -d ' \t')" "TrueTrueTrueTrue"

# 8. THE ONE THE HAPPY PATH MISSES: is Terraform actually READING from S3, or
#    is there still a populated local state file it could silently fall back to?
#    Uploading a copy of state to S3 is not the same as migrating to it. After a
#    real migration the local file is emptied; a local file that still holds
#    resources means two sources of truth and a future overwrite.
LOCAL_RESOURCES=$(python3 -c "
import json,os
p='terraform.tfstate'
if not os.path.exists(p) or os.path.getsize(p)==0: print(0)
else:
    try: print(len(json.load(open(p)).get('resources',[])))
    except Exception: print(0)
")
check "local state file holds ZERO resources after migration" "$LOCAL_RESOURCES" "0"

# 9. And the remote state really does hold them.
REMOTE_RESOURCES=$(aws s3 cp "s3://$BUCKET/$KEY" - 2>/dev/null | python3 -c "
import json,sys
try: print(len(json.load(sys.stdin).get('resources',[])))
except Exception: print(-1)
")
if [ "$REMOTE_RESOURCES" -gt 0 ]; then
  echo "PASS  remote state in S3 holds $REMOTE_RESOURCES resource blocks"
else
  echo "FAIL  remote state in S3 holds no resources (got '$REMOTE_RESOURCES')"; fail=1
fi

echo
[ $fail -eq 0 ] && echo "Lab 8 validation: ALL CHECKS PASSED" || echo "Lab 8 validation: FAILURES ABOVE"
exit $fail

#!/usr/bin/env bash
# Mints a SHORT-LIVED, READ-ONLY AWS console sign-in URL from the credentials
# already configured in this shell. No password is ever typed: STS federation
# exchanges existing credentials for a console session.
#
# The session can only Describe/List/Get. It cannot create, modify or delete
# anything. Default lifetime: 30 minutes.
#
# Usage: ./tools/console_url.sh [destination-console-path]
set -euo pipefail
DEST="${1:-https://console.aws.amazon.com/ec2/home?region=us-east-1}"

CREDS=$(aws sts get-federation-token \
  --name tf-lab-screenshots \
  --duration-seconds 1800 \
  --policy '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Action":["ec2:Describe*","ec2:Get*","s3:List*","s3:Get*","dynamodb:Describe*","dynamodb:List*","tag:Get*","cloudwatch:Describe*","cloudwatch:Get*","cloudwatch:List*"],"Resource":"*"}]}' \
  --output json)

SESSION=$(printf '%s' "$CREDS" | python3 -c '
import json,sys,urllib.parse
c=json.load(sys.stdin)["Credentials"]
print(urllib.parse.quote(json.dumps({
  "sessionId":c["AccessKeyId"],
  "sessionKey":c["SecretAccessKey"],
  "sessionToken":c["SessionToken"]}), safe=""))')

TOKEN=$(curl -s "https://signin.aws.amazon.com/federation?Action=getSigninToken&Session=$SESSION" \
  | python3 -c 'import json,sys; print(json.load(sys.stdin)["SigninToken"])')

python3 - "$TOKEN" "$DEST" <<'PY'
import sys, urllib.parse
token, dest = sys.argv[1], sys.argv[2]
print("https://signin.aws.amazon.com/federation?Action=login"
      "&Issuer=" + urllib.parse.quote("terraform-course-labs", safe="")
      + "&Destination=" + urllib.parse.quote(dest, safe="")
      + "&SigninToken=" + token)
PY

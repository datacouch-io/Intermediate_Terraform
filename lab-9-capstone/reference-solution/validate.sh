#!/usr/bin/env bash
# Lab 9 capstone validation. These are the ACCEPTANCE CRITERIA -- participants
# get this script (or the criteria in the lab document), not the solution.
set -uo pipefail
fail=0
check() { if [ "$2" = "$3" ]; then echo "PASS  $1"; else echo "FAIL  $1 (got '$2', want '$3')"; fail=1; fi }

URL=$(terraform output -raw website_endpoint)
BUCKET=$(terraform output -raw bucket_name)

# 1. The site answers at its root -- proving an index document is configured.
check "HTTP 200 at the website root" \
  "$(curl -s -o /dev/null -w '%{http_code}' --max-time 15 "$URL")" "200"

# 2. Served by S3 itself, not something you accidentally left running.
check "served by AmazonS3" \
  "$(curl -sI --max-time 15 "$URL" | awk -F': ' 'tolower($1)=="server"{gsub(/\r/,"",$2); print $2}')" "AmazonS3"

# 3. A charset, not just a MIME type. Without this every non-ASCII character
#    is mojibake in the browser -- see the lab's Step 5.
check "Content-Type declares a charset" \
  "$(curl -sI --max-time 15 "$URL" | awk -F': ' 'tolower($1)=="content-type"{gsub(/\r/,"",$2); print tolower($2)}')" \
  "text/html; charset=utf-8"

# 4. The custom error document is wired up AND returns a real 404 status.
check "missing page returns 404" \
  "$(curl -s -o /dev/null -w '%{http_code}' --max-time 15 "$URL/no-such-page.html")" "404"
check "missing page serves the CUSTOM error document" \
  "$(curl -sS --max-time 15 "$URL/no-such-page.html" | grep -c 'Served by the S3 website endpoint')" "1"

# 5. No EC2 instance was involved. The capstone is about a resource type the
#    course has not used; falling back to a web server on EC2 is not it.
check "zero EC2 instances in this configuration" \
  "$(terraform state list | grep -c '^aws_instance' || true)" "0"

# 6. The bucket is genuinely public-readable via POLICY, not via an ACL.
#    Modern buckets have ACLs disabled, so acl="public-read" cannot work.
check "a bucket policy exists" \
  "$(aws s3api get-bucket-policy --bucket "$BUCKET" --query 'Policy' --output text >/dev/null 2>&1; echo $?)" "0"
check "no aws_s3_bucket_acl resource is used" \
  "$(terraform state list | grep -c 'aws_s3_bucket_acl' || true)" "0"

# 7. THE ONE THE HAPPY PATH MISSES: is this really the WEBSITE endpoint, or
#    just an object fetched over the REST endpoint? Both return 200 for
#    /index.html. Only the website endpoint serves an index document at the
#    ROOT and a custom error document -- which is the whole feature.
REST="https://$(aws s3api get-bucket-location --bucket "$BUCKET" >/dev/null 2>&1; echo "$BUCKET.s3.us-east-1.amazonaws.com")"
check "REST endpoint root does NOT serve the index (proving these differ)" \
  "$(curl -s -o /dev/null -w '%{http_code}' --max-time 15 "$REST")" "403"
check "REST endpoint DOES serve an explicit object" \
  "$(curl -s -o /dev/null -w '%{http_code}' --max-time 15 "$REST/index.html")" "200"

echo
[ $fail -eq 0 ] && echo "Lab 9 validation: ALL CHECKS PASSED" || echo "Lab 9 validation: FAILURES ABOVE"
exit $fail

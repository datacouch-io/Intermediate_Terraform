#!/bin/bash
# Redacts identifiers from captured lab artifacts before publishing:
#  - ANSI colour codes
#  - 12-digit AWS account ids
#  - the authoring machine's username@hostname (appears in state lock records)
# Usage: ./redact.sh <file>...
for f in "$@"; do
  perl -pi -e '
    s/\e\[[0-9;]*m//g;
    s/\b\d{12}\b/<ACCOUNT_ID>/g;
    s/\bhadez\@[A-Za-z0-9._-]+\b/<USER>@<HOSTNAME>/g;
  ' "$f"
done

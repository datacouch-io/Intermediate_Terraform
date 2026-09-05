#!/usr/bin/env bash
# Builds the Word (.docx) version of every course document from its markdown
# source. Requires pandoc (brew install pandoc).
#
#   ./tools/build_word.sh
#
# Output goes to word/. The markdown remains the source of truth; re-run this
# after editing any .md file.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p word build

build_one() {
  local src="$1" title="$2" out="word/${1%.md}.docx"
  python3 tools/md_for_word.py "$src" "build/$src" >/dev/null
  pandoc "build/$src" \
    --from gfm --to docx \
    --resource-path=".:artifacts" \
    --toc --toc-depth=2 \
    --reference-doc=build/reference-styled.docx \
    --metadata title="$title" \
    --metadata author="DataCouch — Intermediate Terraform" \
    -o "$out"
  printf "  %-52s %8s bytes  %s images\n" \
    "$(basename "$out")" "$(wc -c < "$out" | tr -d ' ')" "$(unzip -l "$out" | grep -c 'word/media/' || true)"
}

build_one 00-shared-setup.md                          "Intermediate Terraform — Shared Setup"
build_one lab-1-first-terraform-project.md            "Lab 1 — Environment Setup & First Terraform Project"
build_one lab-2-variables-locals-data-sources.md      "Lab 2 — Input Variables, Locals & Data Sources"
build_one lab-3-state-drift-import.md                 "Lab 3 — State Deep-Dive, Drift & Import"
build_one lab-4-aws-provider-mini-app.md              "Lab 4 — AWS Provider Deep-Dive: Multi-Resource Mini-App"
build_one lab-5-modules-workspaces.md                 "Lab 5 — Templates, Modules & Workspaces"
build_one lab-6-error-handling-debugging.md           "Lab 6 — Error Handling & Debugging"
build_one lab-7-functions-data-types.md               "Lab 7 — Built-in Functions & Data Type Manipulation"
build_one lab-8-loops-backends.md                     "Lab 8 — Loops, Backends & Scaling EC2"
build_one lab-9-capstone-documentation-deep-dive.md   "Lab 9 (Capstone) — Documentation Deep-Dive Challenge"

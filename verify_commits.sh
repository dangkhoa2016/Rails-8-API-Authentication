#!/usr/bin/env bash
set -euo pipefail

# Verify that every commit on the current branch passes `bin/rubocop -f github`.
#
# Usage:
#   ./verify_commits.sh          # check entire branch (first-commit..HEAD)
#   ./verify_commits.sh HEAD~5   # check last 5 commits only

REF="${1:-}"

# Save the current branch name BEFORE any checkout
ORIGINAL_BRANCH="$(git symbolic-ref --short HEAD 2>/dev/null || true)"

if [ -z "$ORIGINAL_BRANCH" ]; then
  echo "Error: must be on a named branch (currently detached HEAD)." >&2
  exit 1
fi

if [ -z "$REF" ]; then
  FIRST_COMMIT=$(git rev-list --max-parents=0 HEAD)
  RANGE="${FIRST_COMMIT}..HEAD"
else
  RANGE="${REF}..HEAD"
fi

COMMITS=$(git log --oneline --reverse "$RANGE" | awk '{print $1}')
TOTAL=$(echo "$COMMITS" | wc -l | tr -d ' ')
PASS=0
FAIL=0
FAILED_LIST=""

echo "Branch: $ORIGINAL_BRANCH"
echo "Checking $TOTAL commits ..."
echo "---"

for SHA in $COMMITS; do
  short=$(git log -1 --oneline "$SHA" | cut -c1-60)

  git checkout "$SHA" --quiet 2>/dev/null

  if bin/rubocop -f github >/dev/null 2>&1; then
    echo "  PASS  $short"
    PASS=$((PASS + 1))
  else
    echo "  FAIL  $short"
    FAIL=$((FAIL + 1))
    FAILED_LIST="${FAILED_LIST}  $short\n"
  fi
done

# Return to the original branch
git checkout "$ORIGINAL_BRANCH" --quiet 2>/dev/null

echo "---"
echo "Results: $PASS passed, $FAIL failed out of $TOTAL commits"

if [ "$FAIL" -gt 0 ]; then
  echo ""
  echo "Failed commits:"
  echo -e "$FAILED_LIST"
  exit 1
fi

echo "All commits pass rubocop."

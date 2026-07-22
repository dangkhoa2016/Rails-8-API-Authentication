#!/usr/bin/env bash
set -uo pipefail

# Analyze coverage details for each commit.
# Outputs uncovered lines per commit to help plan backfill.
#
# Usage:
#   ./analyze_coverage.sh          # full branch
#   ./analyze_coverage.sh HEAD~10  # last 10 commits

REF="${1:-}"
ORIGINAL_BRANCH="$(git symbolic-ref --short HEAD 2>/dev/null || true)"

if [ -z "$ORIGINAL_BRANCH" ]; then
  echo "Error: must be on a named branch." >&2
  exit 1
fi

if [ -z "$REF" ]; then
  FIRST_COMMIT=$(git rev-list --max-parents=0 HEAD)
  RANGE="${FIRST_COMMIT}..HEAD"
else
  RANGE="${REF}..HEAD"
fi

COMMITS=$(git log --oneline --reverse "$RANGE" | awk '{print $1}')
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

strip_ansi() {
  sed 's/\x1b\[[0-9;]*m//g'
}

echo "Branch: $ORIGINAL_BRANCH"
echo "Analyzing coverage per commit..."
echo ""

for SHA in $COMMITS; do
  SHORT=$(git log -1 --format="%h" "$SHA")
  MSG=$(git log -1 --oneline "$SHA" | cut -c1-72)
  echo "=== $SHORT $MSG ==="

  git checkout "$SHA" --quiet 2>/dev/null

  RAW="$TMPDIR/$SHORT.raw"
  # Run tests, filter gem noise, strip ANSI
  COVERAGE=1 bin/rails test 2>&1 | strip_ansi | grep -v "^Source locally installed gems" | grep -v "^Ignoring " | grep -v "^$" > "$RAW"

  # Parse summary
  SUMMARY=$(grep -oP '^\d+ runs, \d+ assertions.*' "$RAW" | head -1 || true)
  RUNS=$(echo "$SUMMARY" | grep -oP '^\d+(?= runs)')
  FAILURES=$(echo "$SUMMARY" | grep -oP '(?<=, )\d+(?= failures)')
  ERRORS=$(echo "$SUMMARY" | grep -oP '(?<=, )\d+(?= errors)')
  COV=$(grep -oP 'COVERAGE:\s+\K[\d.]+' "$RAW" | tail -1 || true)

  RUNS=${RUNS:-0}
  FAILURES=${FAILURES:-0}
  ERRORS=${ERRORS:-0}
  COV=${COV:-N/A}

  echo "  Tests: $RUNS | Failures: $FAILURES | Errors: $ERRORS | Coverage: $COV%"

  # Show coverage details
  if [ "$COV" != "N/A" ]; then
    grep -A 20 "coverage.*file.*lines.*missed" "$RAW" | grep -E "^\|" | sed 's/^/    /'
  fi

  echo ""
done

git checkout "$ORIGINAL_BRANCH" --quiet 2>/dev/null
echo "Done."

#!/usr/bin/env bash
set -uo pipefail

# Run COVERAGE=1 bin/rails test on every commit and generate a markdown report.
#
# Usage:
#   ./verify_tests.sh                  # check entire branch
#   ./verify_tests.sh HEAD~5           # check last 5 commits
#   ./verify_tests.sh HEAD~5 report.md # custom output file

REF="${1:-}"
REPORT_FILE="${2:-test_report.md}"

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
TOTAL=$(echo "$COMMITS" | wc -l | tr -d ' ')

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

PASS_COUNT=0
FAIL_COUNT=0
ERROR_COUNT=0
idx=0

echo "Branch: $ORIGINAL_BRANCH"
echo "Checking $TOTAL commits ..."
echo ""

for SHA in $COMMITS; do
  idx=$((idx + 1))
  MSG=$(git log -1 --oneline "$SHA" | cut -c1-72)
  SHORT=$(git log -1 --format="%h" "$SHA")
  echo "[$idx/$TOTAL] $MSG"

  git checkout "$SHA" --quiet 2>/dev/null

  RAW="$TMPDIR/$SHORT.raw"
  COVERAGE=1 bin/rails test 2>&1 | tee "$RAW"
  EXIT_CODE=${PIPESTATUS[0]}

  # Strip ANSI color codes for reliable parsing
  sed -i 's/\x1b\[[0-9;]*m//g' "$RAW"

  # Parse from the "Finished" summary line: "XX runs, XX assertions, X failures, X errors"
  SUMMARY=$(grep -oP '^\d+ runs, \d+ assertions.*' "$RAW" | head -1 || true)
  RUNS=$(echo "$SUMMARY" | grep -oP '^\d+(?= runs)')
  ASSERTIONS=$(echo "$SUMMARY" | grep -oP '(?<=, )\d+(?= assertions)')
  FAILURES=$(echo "$SUMMARY" | grep -oP '(?<=, )\d+(?= failures)')
  ERRORS=$(echo "$SUMMARY" | grep -oP '(?<=, )\d+(?= errors)')

  RUNS=${RUNS:-0}
  ASSERTIONS=${ASSERTIONS:-0}
  FAILURES=${FAILURES:-0}
  ERRORS=${ERRORS:-0}

  # Parse coverage: "COVERAGE:  XX.XX%"
  COV=$(grep -oP 'COVERAGE:\s+\K[\d.]+' "$RAW" | tail -1 || true)
  COV=${COV:-N/A}

  if [ "$EXIT_CODE" -eq 0 ] && [ "$FAILURES" = "0" ] && [ "$ERRORS" = "0" ]; then
    STATUS="PASS"
    PASS_COUNT=$((PASS_COUNT + 1))
  elif [ "$FAILURES" != "0" ]; then
    STATUS="FAIL"
    FAIL_COUNT=$((FAIL_COUNT + 1))
  else
    STATUS="ERROR"
    ERROR_COUNT=$((ERROR_COUNT + 1))
  fi

  # Extract failure/error details
  DETAILS=""
  if [ "$FAILURES" != "0" ] || [ "$ERRORS" != "0" ]; then
    DETAILS=$(grep -B1 -A 3 "^Failure:\|^Error:" "$RAW" 2>/dev/null || true)
  fi

  # Append to report
  {
    echo "## $idx. \`$SHORT\` $MSG"
    echo ""
    echo "| Metric | Value |"
    echo "|--------|-------|"
    echo "| Status | **$STATUS** |"
    echo "| Tests | $RUNS runs / $ASSERTIONS assertions |"
    echo "| Failures | $FAILURES |"
    echo "| Errors | $ERRORS |"
    echo "| Coverage | ${COV}% |"
    echo ""
    if [ -n "$DETAILS" ]; then
      echo "<details>"
      echo "<summary>Failure/Error details</summary>"
      echo ""
      echo '```'
      echo "$DETAILS"
      echo '```'
      echo "</details>"
      echo ""
    fi
  } >> "$TMPDIR/report.md"

  echo ""
done

git checkout "$ORIGINAL_BRANCH" --quiet 2>/dev/null

# Build final report
{
  echo "# Test Report — \`$ORIGINAL_BRANCH\`"
  echo ""
  echo "| | |"
  echo "|---|---|"
  echo "| **Branch** | \`$ORIGINAL_BRANCH\` |"
  echo "| **Date** | $(date '+%Y-%m-%d %H:%M:%S') |"
  echo "| **Commits** | $TOTAL |"
  echo ""
  echo "## Summary"
  echo ""
  echo "| Status | Count |"
  echo "|--------|-------|"
  echo "| PASS | $PASS_COUNT |"
  echo "| FAIL | $FAIL_COUNT |"
  echo "| ERROR | $ERROR_COUNT |"
  echo "| **Total** | **$TOTAL** |"
  echo ""
  if [ "$FAIL_COUNT" -eq 0 ] && [ "$ERROR_COUNT" -eq 0 ]; then
    echo "> All commits pass with 0 failures and 0 errors."
  else
    echo "> **$FAIL_COUNT** failures, **$ERROR_COUNT** errors detected."
  fi
  echo ""
  echo "---"
  echo ""
  echo "## Per-Commit Details"
  echo ""
  cat "$TMPDIR/report.md"
} > "$REPORT_FILE"

echo "=== Report: $REPORT_FILE ==="
echo "Summary: $PASS_COUNT pass, $FAIL_COUNT fail, $ERROR_COUNT error / $TOTAL"

if [ "$FAIL_COUNT" -gt 0 ] || [ "$ERROR_COUNT" -gt 0 ]; then
  exit 1
fi

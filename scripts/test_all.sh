#!/bin/bash
# =============================================================================
#  Master API Test Suite Runner
#  Executes both User and Admin bash test scripts to verify 100% of project routes.
#
#  Usage:
#    bash scripts/test_all.sh
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test_helpers.sh"

FAILED=0

run_suite() {
  local name="$1" script="$2"
  echo -e "\n${CYAN}>>> Running $name...${NC}"
  if bash "$SCRIPT_DIR/$script"; then
    echo -e "${GREEN}✓ $name PASSED${NC}"
  else
    echo -e "${RED}✗ $name FAILED${NC}"
    FAILED=1
  fi
}

echo -e "${CYAN}=====================================================${NC}"
echo -e "${CYAN}   RAILS 8 API AUTHENTICATION - FULL SUITE TEST      ${NC}"
echo -e "${CYAN}=====================================================${NC}"

run_suite "Regular User Test Suite (test_user.sh)" "test_user.sh"
run_suite "Admin Test Suite (test_admin.sh)" "test_admin.sh"

echo ""
if [ "$FAILED" -eq 0 ]; then
  echo -e "${GREEN}=====================================================${NC}"
  echo -e "${GREEN}   ALL API TEST SUITES PASSED SUCCESSFULLY! (100%)  ${NC}"
  echo -e "${GREEN}=====================================================${NC}"
else
  echo -e "${RED}=====================================================${NC}"
  echo -e "${RED}   ONE OR MORE TEST SUITES FAILED - SEE OUTPUT ABOVE${NC}"
  echo -e "${RED}=====================================================${NC}"
  exit 1
fi

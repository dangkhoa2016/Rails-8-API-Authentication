# =============================================================================
#  Configuration
#  Usage:
#    source manual/config.sh
#    export TEST_JWT_TOKEN="<your-token>"
# =============================================================================

BASE_URL="${API_BASE_URL:-http://localhost:4000}"
TOKEN="${TEST_JWT_TOKEN:-<your-jwt-token-here>}"

# Shortcut for authenticated requests
alias api='curl -s -H "Content-Type: application/json" -H "Authorization: Bearer $TOKEN"'

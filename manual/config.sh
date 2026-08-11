# =============================================================================
#  Configuration
#  Usage:
#    source manual/config.sh
#    export TEST_JWT_TOKEN="<your-token>"
# =============================================================================

BASE_URL="${API_BASE_URL:-http://localhost:4000}"
TOKEN="${TEST_JWT_TOKEN:-<your-jwt-token-here>}"

# Header transporting the access JWT (default: Authorization).
# Set JWT_AUTH_HEADER=X-Authorization when running behind Beam.cloud.
JWT_AUTH_HEADER="${JWT_AUTH_HEADER:-Authorization}"

# Shortcut for authenticated requests.
# A function (not an alias) so arguments are forwarded safely and the script
# works in non-interactive shells.
api() {
  curl -sS \
    -H "Content-Type: application/json" \
    -H "${JWT_AUTH_HEADER}: Bearer ${TOKEN}" \
    "$@"
}

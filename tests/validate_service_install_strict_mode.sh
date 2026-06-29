#!/bin/bash
# ==============================================================================
# Test: validate_service_install_strict_mode.sh
# Purpose: Ensure every script in scripts/service_install/ has set -euo pipefail.
# ==============================================================================

set -euo pipefail

REPO_ROOT="${REPO_ROOT_OVERRIDE:-$(cd "$(dirname "$0")/.." && pwd)}"
SERVICE_DIR="$REPO_ROOT/scripts/service_install"
PASS=0
FAIL=0
FAILURES=()

echo "=== Validating set -euo pipefail in service_install scripts ==="
echo ""

for script in "$SERVICE_DIR"/*.sh; do
    [ -f "$script" ] || continue
    name=$(basename "$script")

    # Check for set -euo pipefail anywhere in the file (must exist)
    if grep -q 'set -euo pipefail' "$script"; then
        echo "  [PASS] $name"
        PASS=$((PASS + 1))
    else
        echo "  [FAIL] $name - missing 'set -euo pipefail'"
        FAIL=$((FAIL + 1))
        FAILURES+=("$name")
    fi
done

echo ""
echo "Results: $PASS passed, $FAIL failed"

if [ $FAIL -gt 0 ]; then
    echo ""
    echo "Scripts missing strict mode:"
    for f in "${FAILURES[@]}"; do
        echo "  - $f"
    done
    exit 1
fi

echo "All service_install scripts have strict mode enabled."
exit 0

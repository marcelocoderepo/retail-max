#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# validate-all.sh - Validate Terraform for all environments
#
# Runs terraform init (no backend) + validate + fmt check for dev, hml, prd.
# Use in CI or locally before creating a PR.
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
ENVS=("dev" "hml" "prd")
ERRORS=0

echo "==> Validating all environments..."
echo ""

for env in "${ENVS[@]}"; do
  ENV_DIR="$ROOT_DIR/environments/$env"
  echo "--- $env ---"

  if [ ! -d "$ENV_DIR" ]; then
    echo "  ERROR: Directory $ENV_DIR not found"
    ERRORS=$((ERRORS + 1))
    continue
  fi

  cd "$ENV_DIR"

  echo "  terraform init -backend=false..."
  if ! terraform init -backend=false -input=false > /dev/null 2>&1; then
    echo "  FAIL: terraform init"
    ERRORS=$((ERRORS + 1))
    continue
  fi

  echo "  terraform validate..."
  if ! terraform validate; then
    echo "  FAIL: terraform validate"
    ERRORS=$((ERRORS + 1))
  fi

  echo "  terraform fmt -check..."
  if ! terraform fmt -check -recursive > /dev/null 2>&1; then
    echo "  FAIL: terraform fmt (run 'terraform fmt -recursive' to fix)"
    ERRORS=$((ERRORS + 1))
  fi

  echo "  OK"
  echo ""
done

if [ $ERRORS -gt 0 ]; then
  echo "==> FAILED: $ERRORS error(s) found"
  exit 1
else
  echo "==> All environments validated successfully"
fi

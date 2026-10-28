#!/usr/bin/env bash
# ==============================================================================
# DPI Center — Environment Configuration Validator (.env)
# ==============================================================================
# Purpose:
#   Validates the root .env configuration before running bootstrap or Terraform.
#   Performs static syntax/format checks and optional live GCP pre-flight checks.
#
# Usage:
#   ./scripts/check_env.sh [OPTIONS] [ENV_FILE_PATH]
#
# Options:
#   -h, --help        Show help and exit
#   -e, --env <path>  Explicit path to .env file
#   --skip-gcp        Skip live GCP API pre-flight checks (static syntax only)
# ==============================================================================

set -euo pipefail

# --- Color Definitions ---
readonly COLOR_GREEN="\033[0;32m"
readonly COLOR_RED="\033[0;31m"
readonly COLOR_YELLOW="\033[0;33m"
readonly COLOR_BLUE="\033[0;34m"
readonly COLOR_RESET="\033[0m"

# Find repository root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DEFAULT_ENV_FILE="${REPO_ROOT}/.env"

ENV_FILE="${DEFAULT_ENV_FILE}"
SKIP_GCP=false
ERRORS=0
WARNINGS=0

print_help() {
  cat <<'EOF'
Usage:
  ./scripts/check_env.sh [OPTIONS] [ENV_FILE_PATH]

Options:
  -h, --help        Show this help message and exit.
  -e, --env <path>  Path to an alternate .env configuration file.
  --skip-gcp        Skip live GCP API checks (static syntax validation only).

Examples:
  ./scripts/check_env.sh
  ./scripts/check_env.sh --skip-gcp
  ./scripts/check_env.sh -e /custom/path/.env

Configuration Parameters in .env:
  DOMAIN_NAME          [Required] Subdomain name and project prefix (<domain>-mgmt)
  BILLING_ACCOUNT_ID   [Required] GCP Billing Account ID (e.g. '01XXXX-XXXXXX-XXXXXX')
  PARENT_DOMAIN        [Optional] Defaults to 'dpi.ait.ac.th'. Leave empty for standalone apex domains.
  REGION               [Optional] Defaults to 'asia-southeast1' (Singapore)
  PROJECT_ADMINS       [Optional] Comma-separated list of admin emails (Editor role)
  PROJECT_MEMBERS      [Optional] Comma-separated list of viewer emails (Viewer role)
EOF
}

# --- Parse Arguments ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      print_help
      exit 0
      ;;
    -e|--env)
      if [[ -n "${2:-}" ]]; then
        ENV_FILE="$2"
        shift 2
      else
        echo -e "${COLOR_RED}❌ ERROR: --env requires a path argument.${COLOR_RESET}"
        exit 1
      fi
      ;;
    --skip-gcp)
      SKIP_GCP=true
      shift
      ;;
    *)
      ENV_FILE="$1"
      shift
      ;;
  esac
done

echo "================================================================="
echo " 🔍 DPI Center — Environment Configuration Validator"
echo "================================================================="
echo " Target File: ${ENV_FILE}"
echo "================================================================="

# --- 1. Check File Existence ---
if [[ ! -f "${ENV_FILE}" ]]; then
  echo -e "${COLOR_RED}[FAIL] Configuration file not found at: ${ENV_FILE}${COLOR_RESET}"
  echo ""
  echo "👉 Quick Setup:"
  echo "   cp .env.example .env"
  echo "   nano .env"
  echo "   ./scripts/check_env.sh"
  exit 1
fi

# Load variables
set -a
# shellcheck disable=SC1090
source "${ENV_FILE}"
set +a

log_ok() {
  local key="$1"
  local val="$2"
  printf " ${COLOR_GREEN}[OK]${COLOR_RESET}   %-22s : %s\n" "${key}" "${val}"
}

log_fail() {
  local key="$1"
  local reason="$2"
  printf " ${COLOR_RED}[FAIL]${COLOR_RESET} %-22s : %s\n" "${key}" "${reason}"
  ERRORS=$((ERRORS + 1))
}

log_warn() {
  local key="$1"
  local reason="$2"
  printf " ${COLOR_YELLOW}[WARN]${COLOR_RESET} %-22s : %s\n" "${key}" "${reason}"
  WARNINGS=$((WARNINGS + 1))
}

echo ""
echo "--- [1/2] Static Configuration Checks ---"

# --- 2. Check DOMAIN_NAME ---
DOMAIN_NAME="${DOMAIN_NAME:-}"
if [[ -z "${DOMAIN_NAME}" ]]; then
  log_fail "DOMAIN_NAME" "Variable is empty or unset."
elif [[ "${DOMAIN_NAME}" == "example-domain" ]]; then
  log_fail "DOMAIN_NAME" "Still set to placeholder 'example-domain'. Set to real grant slug (e.g. 'mosip-asia')."
elif [[ ! "${DOMAIN_NAME}" =~ ^[a-z0-9-]+$ ]]; then
  log_fail "DOMAIN_NAME" "Must contain only lowercase letters, numbers, and hyphens."
elif [[ ${#DOMAIN_NAME} -gt 25 ]]; then
  log_fail "DOMAIN_NAME" "Too long (${#DOMAIN_NAME} chars, max 25 chars because project ID suffix adds '-mgmt')."
else
  log_ok "DOMAIN_NAME" "${DOMAIN_NAME} (mgmt project: ${DOMAIN_NAME}-mgmt)"
fi

# --- 3. Check BILLING_ACCOUNT_ID ---
BILLING_ACCOUNT_ID="${BILLING_ACCOUNT_ID:-}"
if [[ -z "${BILLING_ACCOUNT_ID}" ]]; then
  log_warn "BILLING_ACCOUNT_ID" "Empty (OK for workload developers; required for Day-0 bootstrap or relinking billing)"
elif [[ "${BILLING_ACCOUNT_ID}" =~ ^01XXXX || "${BILLING_ACCOUNT_ID}" =~ XXXX ]]; then
  log_fail "BILLING_ACCOUNT_ID" "Still set to placeholder '${BILLING_ACCOUNT_ID}'. Enter real ID from GCP Console."
elif [[ ! "${BILLING_ACCOUNT_ID}" =~ ^[A-Z0-9]{6}-[A-Z0-9]{6}-[A-Z0-9]{6}$ ]]; then
  log_fail "BILLING_ACCOUNT_ID" "Invalid format '${BILLING_ACCOUNT_ID}'. Must be XXXXXX-XXXXXX-XXXXXX."
else
  # Mask for display
  MASKED_BILLING="${BILLING_ACCOUNT_ID:0:6}-XXXXXX-${BILLING_ACCOUNT_ID:15:6}"
  log_ok "BILLING_ACCOUNT_ID" "${MASKED_BILLING} (Valid GCP format)"
fi

# --- 4. Check PARENT_DOMAIN ---
PARENT_DOMAIN="${PARENT_DOMAIN:-}"
if [[ -z "${PARENT_DOMAIN}" ]]; then
  log_ok "PARENT_DOMAIN" "None (Cloud DNS will be skipped)"
elif [[ ! "${PARENT_DOMAIN}" =~ ^[a-z0-9.-]+$ ]]; then
  log_fail "PARENT_DOMAIN" "Invalid domain format '${PARENT_DOMAIN}'."
else
  log_ok "PARENT_DOMAIN" "${PARENT_DOMAIN}"
fi

# --- 5. Check REGION ---
REGION="${REGION:-asia-southeast1}"
if [[ ! "${REGION}" =~ ^[a-z]+-[a-z]+[0-9]+$ ]]; then
  log_fail "REGION" "Invalid region format '${REGION}' (e.g. asia-southeast1)."
else
  log_ok "REGION" "${REGION} (Singapore)"
fi

# --- 6. Check PROJECT_ADMINS ---
PROJECT_ADMINS="${PROJECT_ADMINS:-}"
if [[ -z "${PROJECT_ADMINS}" ]]; then
  log_ok "PROJECT_ADMINS" "None specified (Current user will be project owner)"
else
  INVALID_EMAILS=0
  IFS=',' read -ra EMAILS <<< "${PROJECT_ADMINS}"
  for email in "${EMAILS[@]}"; do
    clean_email=$(echo "${email}" | xargs)
    if [[ ! "${clean_email}" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
      log_fail "PROJECT_ADMINS" "Invalid email format: '${clean_email}'"
      INVALID_EMAILS=1
    fi
  done
  if [[ ${INVALID_EMAILS} -eq 0 ]]; then
    log_ok "PROJECT_ADMINS" "${PROJECT_ADMINS}"
  fi
fi

echo ""
echo "--- [2/2] Live Google Cloud IAM & Permission Readiness Checks ---"

if [[ "${SKIP_GCP}" == "true" ]]; then
  echo -e " ${COLOR_YELLOW}[SKIP]${COLOR_RESET} Skipping GCP API checks (--skip-gcp requested)."
elif ! command -v gcloud >/dev/null 2>&1; then
  log_warn "gcloud CLI" "gcloud command not found on PATH. Skipping live checks."
else
  export CLOUDSDK_METRICS_ENVIRONMENT="${CLOUDSDK_METRICS_ENVIRONMENT:-datacloud.antigravity}"
  ACTIVE_ACCOUNT=$(gcloud config get-value account 2>/dev/null || true)
  if [[ -z "${ACTIVE_ACCOUNT}" ]]; then
    log_fail "gcloud Auth" "No active account found. Run 'gcloud auth login' first."
  else
    log_ok "gcloud Auth" "Authenticated as ${ACTIVE_ACCOUNT}"

    echo ""
    echo " Verifying required permissions for ${ACTIVE_ACCOUNT}..."
    echo " -----------------------------------------------------------------"

    # Check 1: Billing Account Status (Active & Open)
    BILLING_OPEN=false
    if [[ ! "${BILLING_ACCOUNT_ID}" =~ XXXX && -n "${BILLING_ACCOUNT_ID}" ]]; then
      if ERR_MSG=$(gcloud billing accounts describe "${BILLING_ACCOUNT_ID}" 2>&1 >/dev/null); then
        IS_OPEN=$(gcloud billing accounts describe "${BILLING_ACCOUNT_ID}" --format="value(open)" 2>/dev/null || true)
        if [[ "${IS_OPEN}" == "True" ]]; then
          BILLING_OPEN=true
          log_ok "1. Billing Status" "Billing Account ${MASKED_BILLING} is active and OPEN"
        else
          log_fail "1. Billing Status" "Billing Account ${MASKED_BILLING} found but status is not OPEN"
        fi
      else
        log_fail "1. Billing Status" "Cannot describe Billing Account ${MASKED_BILLING}: $(echo "${ERR_MSG}" | head -n 1)"
      fi
    fi

    # Check 2: Billing Project Linking Permission (billing.user / billing.admin)
    if [[ "${BILLING_OPEN}" == "true" ]]; then
      if ERR_MSG=$(gcloud billing projects list --billing-account="${BILLING_ACCOUNT_ID}" --limit=1 2>&1 >/dev/null); then
        log_ok "2. Billing Linker" "Verified permission to link projects to ${MASKED_BILLING} (Role: billing.user / billing.admin)"
      else
        log_fail "2. Billing Linker" "Cannot link to ${MASKED_BILLING}: $(echo "${ERR_MSG}" | head -n 1)"
      fi
    fi

    # Check 3: State Storage Bucket Availability (Global GCS Namespace)
    if [[ -n "${PARENT_DOMAIN}" ]]; then
      PARENT_SLUG="${PARENT_DOMAIN//./-}"
      DEFAULT_STATE_BUCKET="${DOMAIN_NAME}-${PARENT_SLUG}-tfstate"
    else
      DEFAULT_STATE_BUCKET="${DOMAIN_NAME}-tfstate"
    fi
    STATE_BUCKET="${STATE_BUCKET:-${DEFAULT_STATE_BUCKET}}"
    BUCKET_TEST_OUTPUT=$(gcloud storage buckets describe "gs://${STATE_BUCKET}" 2>&1 || true)
    if echo "${BUCKET_TEST_OUTPUT}" | grep -qi "404\|NotFound\|does not exist"; then
      log_ok "3. State Bucket" "Name 'gs://${STATE_BUCKET}' is AVAILABLE globally"
    elif echo "${BUCKET_TEST_OUTPUT}" | grep -qi "403\|AccessDenied\|Forbidden"; then
      log_fail "3. State Bucket" "'gs://${STATE_BUCKET}' is globally taken by another GCP user. Set STATE_BUCKET in .env."
    elif echo "${BUCKET_TEST_OUTPUT}" | grep -qi "storage.googleapis.com"; then
      log_ok "3. State Bucket" "Bucket 'gs://${STATE_BUCKET}' already exists and is accessible"
    else
      log_ok "3. State Bucket" "Bucket name verified"
    fi
  fi
fi

echo ""
echo "================================================================="
if [[ ${ERRORS} -eq 0 ]]; then
  echo -e "${COLOR_GREEN} ✅ All configuration & readiness checks PASSED! (0 errors, ${WARNINGS} warnings)${COLOR_RESET}"
  echo " You are ready to proceed with:"
  echo "   ./scripts/bootstrap_domain.sh --plan"
  echo "================================================================="
  exit 0
else
  echo -e "${COLOR_RED} ❌ Readiness check FAILED with ${ERRORS} error(s) and ${WARNINGS} warning(s).${COLOR_RESET}"
  echo " Please resolve the reported permission/configuration errors before continuing."
  echo ""
  echo " 💡 Quick Remediation Guide:"
  echo "    To grant Billing linking rights:"
  echo "       In GCP Console -> Billing -> Select '${MASKED_BILLING:-<billing-account-id>}' -> Account Management (or Permissions panel)"
  echo "       Add '${ACTIVE_ACCOUNT:-<your-email>}' with role 'Billing Account User' (roles/billing.user)."
  echo "================================================================="
  exit 1
fi

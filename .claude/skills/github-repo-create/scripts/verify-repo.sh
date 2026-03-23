#!/usr/bin/env bash
# verify-repo.sh - GitHub リポジトリ作成後の検証スクリプト
# Usage: verify-repo.sh <owner/repo> <private|public> [gitignore-template]
#   gitignore-template を指定した場合、.gitignore の存在を必須チェックする
#   省略した場合、.gitignore チェックはスキップする

set -euo pipefail

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# --- Args ---
if [[ $# -lt 2 ]]; then
  echo "Usage: $0 <owner/repo> <private|public> [gitignore-template]"
  exit 2
fi

REPO="$1"
EXPECTED_VISIBILITY="$2"
GITIGNORE_TEMPLATE="${3:-}"

if [[ ! "$EXPECTED_VISIBILITY" =~ ^(private|public)$ ]]; then
  echo -e "${RED}[ERROR]${NC} visibility must be 'private' or 'public', got: $EXPECTED_VISIBILITY"
  exit 2
fi

# --- Counters ---
PASS=0
FAIL=0
TOTAL=0

check() {
  local label="$1"
  local result="$2"
  local detail="$3"
  TOTAL=$((TOTAL + 1))
  if [[ "$result" == "pass" ]]; then
    PASS=$((PASS + 1))
    echo -e "${GREEN}[PASS]${NC} ${label}: ${detail}"
  else
    FAIL=$((FAIL + 1))
    echo -e "${RED}[FAIL]${NC} ${label}: ${detail}"
  fi
}

# --- Fetch repo info ---
if ! REPO_JSON=$(gh repo view "$REPO" --json isPrivate,defaultBranchRef,description 2>&1); then
  echo -e "${RED}[ERROR]${NC} リポジトリ ${REPO} の情報を取得できません"
  echo "$REPO_JSON"
  exit 1
fi

IS_PRIVATE=$(echo "$REPO_JSON" | jq -r '.isPrivate')
DEFAULT_BRANCH=$(echo "$REPO_JSON" | jq -r '.defaultBranchRef.name // "N/A"')
DESCRIPTION=$(echo "$REPO_JSON" | jq -r '.description // ""')

# --- Check 1: Visibility ---
if [[ "$EXPECTED_VISIBILITY" == "private" ]]; then
  if [[ "$IS_PRIVATE" == "true" ]]; then
    check "visibility" "pass" "private (expected: private)"
  else
    check "visibility" "fail" "public (expected: private) <- SECURITY RISK"
  fi
else
  if [[ "$IS_PRIVATE" == "false" ]]; then
    check "visibility" "pass" "public (expected: public)"
  else
    check "visibility" "fail" "private (expected: public)"
  fi
fi

# --- Check 2: Default branch ---
if [[ "$DEFAULT_BRANCH" == "main" ]]; then
  check "default branch" "pass" "main"
else
  check "default branch" "fail" "${DEFAULT_BRANCH} (expected: main)"
fi

# --- Check 3: Description ---
if [[ -n "$DESCRIPTION" ]]; then
  check "description" "pass" "\"${DESCRIPTION}\""
else
  check "description" "fail" "empty"
fi

# --- Check 4: README ---
README_CHECK=$(gh api "/repos/${REPO}/contents/README.md" --jq .name 2>/dev/null || echo "")
if [[ "$README_CHECK" == "README.md" ]]; then
  check "README.md" "pass" "exists"
else
  check "README.md" "fail" "not found"
fi

# --- Check 5: .gitignore ---
GITIGNORE_CHECK=$(gh api "/repos/${REPO}/contents/.gitignore" --jq .name 2>/dev/null || echo "")
if [[ -n "$GITIGNORE_TEMPLATE" ]]; then
  # gitignore が指定された場合: 存在必須
  if [[ "$GITIGNORE_CHECK" == ".gitignore" ]]; then
    check ".gitignore" "pass" "exists (template: ${GITIGNORE_TEMPLATE})"
  else
    check ".gitignore" "fail" "not found (expected: ${GITIGNORE_TEMPLATE})"
  fi
else
  # gitignore 未指定: 存在チェックをスキップ
  if [[ "$GITIGNORE_CHECK" == ".gitignore" ]]; then
    check ".gitignore" "pass" "exists (not requested, but present)"
  else
    check ".gitignore" "pass" "skipped (not requested)"
  fi
fi

# --- Check 6: Local directory ---
OWNER=$(echo "$REPO" | cut -d'/' -f1)
REPO_NAME=$(echo "$REPO" | cut -d'/' -f2)
GHQ_ROOT=$(ghq root 2>/dev/null || echo "")

if [[ -n "$GHQ_ROOT" ]]; then
  LOCAL_PATH="${GHQ_ROOT}/github.com/${OWNER}/${REPO_NAME}"
  if [[ -d "$LOCAL_PATH" ]]; then
    check "local directory" "pass" "${LOCAL_PATH}"
  else
    check "local directory" "fail" "${LOCAL_PATH} does not exist"
  fi
else
  check "local directory" "fail" "ghq root not found"
fi

# --- Summary ---
echo "---"
if [[ "$FAIL" -eq 0 ]]; then
  echo -e "${GREEN}All checks passed (${PASS}/${TOTAL})${NC}"
  exit 0
else
  echo -e "${RED}${FAIL} check(s) failed${NC} (${PASS}/${TOTAL} passed)"
  exit 1
fi

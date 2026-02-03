#!/usr/bin/env bash
#
# Registry Cache Warming Script - Polling-Based
# Monitors GitHub for merged Renovate PRs and pre-caches Docker images
#

set -euo pipefail

# Configuration
GITHUB_REPO="${GITHUB_REPO:-Niceplace/labrador-maison}"
GITHUB_TOKEN="${GITHUB_TOKEN:-}"
REGISTRY_URL="${REGISTRY_URL:-registry.thinkcenter.dev}"
CACHE_DIR="${CACHE_DIR:-/tmp/registry-cache}"
STATE_FILE="${STATE_FILE:-${CACHE_DIR}/last-check.txt}"
POLL_INTERVAL_MINUTES="${POLL_INTERVAL_MINUTES:-15}"

# Colors
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

# Check dependencies
for cmd in docker jq curl; do
    command -v "$cmd" &>/dev/null || { log_error "Missing: $cmd"; exit 1; }
done

[[ -z "$GITHUB_TOKEN" ]] && { log_error "GITHUB_TOKEN required"; exit 1; }

mkdir -p "$CACHE_DIR"
touch "$STATE_FILE"

# Main polling loop
while true; do
    log_info "=========================================="
    log_info "Registry Cache Warming Check"
    log_info "=========================================="
    date

    # Get last check time
    last_check=$(cat "$STATE_FILE" 2>/dev/null || echo "0")
    current_time=$(date +%s)

    # Check if enough time has passed
    if [[ $((current_time - last_check)) -ge $((POLL_INTERVAL_MINUTES * 60)) ]]; then
        # Fetch merged Renovate PRs from last 24 hours
        since_date=$(date -u -d "24 hours ago" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || \
                     date -u -v-24H +"%Y-%m-%dT%H:%M:%SZ")

        log_info "Fetching merged Renovate PRs since ${since_date}"

        prs_json=$(curl -s \
            -H "Authorization: token ${GITHUB_TOKEN}" \
            -H "Accept: application/vnd.github.v3+json" \
            "https://api.github.com/repos/${GITHUB_REPO}/pulls?state=closed&sort=updated&direction=desc&per_page=20" 2>/dev/null)

        # Extract merged Renovate PRs
        merged_prs=$(echo "$prs_json" | jq -r "
            [.[] | select(.merged_at != null) | select(.merged_at >= \"${since_date}\") |
            select(.user.login == \"renovate[bot]\" or .title | contains(\"Renovate\"))]
        ")

        pr_count=$(echo "$merged_prs" | jq -s 'length')

        if [[ "$pr_count" -gt 0 ]]; then
            log_info "Found ${pr_count} merged Renovate PR(s)"

            # Get unique commit SHAs
            commit_shas=$(echo "$merged_prs" | jq -r '.[].merge_commit_sha' | sort -u)

            # Extract and cache images
            declare -A images

            for sha in $commit_shas; do
                log_info "Checking commit ${sha:0:7}"

                # Get changed files
                files=$(curl -s \
                    -H "Authorization: token ${GITHUB_TOKEN}" \
                    "https://api.github.com/repos/${GITHUB_REPO}/commits/${sha}" | \
                    jq -r '.files[].filename' 2>/dev/null)

                for file in $files; do
                    if [[ "$file" =~ (docker-compose|concourse-ci/tasks) ]]; then
                        # Fetch file content and extract images
                        file_url="https://raw.githubusercontent.com/${GITHUB_REPO}/main/${file}"
                        file_content=$(curl -s "$file_url" 2>/dev/null || echo "")

                        if [[ -n "$file_content" ]]; then
                            while IFS= read -r line; do
                                if [[ "$line" =~ image:[[:space:]]*['\"]?([^'\"[:space:]]+) ]]; then
                                    img="${BASH_REMATCH[1]}"
                                    img="${img%%@*}"
                                    if [[ ! "$img" =~ ^(localhost|127\.0\.0\.1|\.) ]] && [[ -n "$img" ]]; then
                                        images["$img"]=1
                                    fi
                                fi
                            done <<< "$file_content"
                        fi
                    fi
                done
            done

            # Cache unique images
            if [[ ${#images[@]} -gt 0 ]]; then
                log_info "Images to cache: ${#images[@]}"

                for img in "${!images[@]}"; do
                    log_info "Pulling: $img"
                    if docker pull "$img"; then
                        log_success "Cached: $img"
                    else
                        log_warning "Failed: $img"
                    fi
                done
            fi
        else
            log_info "No recent Renovate PRs found"
        fi

        # Update last check time
        date +%s > "$STATE_FILE"
    else
        log_info "Last check too recent ($(date -r "$STATE_FILE" +"%H:%M:%S")), skipping"
    fi

    # Wait before next check
    log_info "Next check in ${POLL_INTERVAL_MINUTES} minutes..."
    sleep $((POLL_INTERVAL_MINUTES * 60))
done

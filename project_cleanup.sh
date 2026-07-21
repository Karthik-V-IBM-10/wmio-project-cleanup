#!/bin/bash

################################################################################
# Project Cleanup Script
# 
# This script cleans up projects, workflows, and flowservices in a webMethods.io
# tenant based on an exception list and project prefix filters.
#
# Supports both CA3S (Basic Auth) and MCSP (API Key) authentication
#
# Based on: ProjectCleanup.feature and ProjectAPIPage.java
# Author: Automated conversion from Java implementation
################################################################################

# Better error handling - don't exit the shell on error
set -o pipefail  # Catch errors in pipes

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration variables (can be overridden by environment variables or command line)
WMIO_TENANT_URL="${WMIO_TENANT_URL:-}"
WMIO_USERNAME="${WMIO_USERNAME:-}"
WMIO_PASSWORD="${WMIO_PASSWORD:-}"
APP_ENV="${APP_ENV:-}"
INSTANCE_API_KEY="${INSTANCE_API_KEY:-}"
EXCEPTION_LIST_FILE="${EXCEPTION_LIST_FILE:-DefaultExceptionList.json}"
PROJECT_PREFIX_NAMES="${PROJECT_PREFIX_NAMES:-Auto_,Man_,BVT_}"
DRY_RUN="${DRY_RUN:-false}"
REQUEST_TIMEOUT="${REQUEST_TIMEOUT:-180}"  # 3 minutes in seconds

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXCEPTION_LIST_DIR="${SCRIPT_DIR}/exception_lists"

# MCSP session tokens (populated once by fetch_mcsp_tokens)
MCSP_AUTHTOKEN=""
MCSP_COOKIE=""
MCSP_CSRF=""

# Counters
REQUIRED_PROJECTS=0
PROJECTS_BEFORE_CLEANUP=0
PROJECTS_AFTER_CLEANUP=0
PROJECTS_NOT_DELETED=0

# Arrays to track projects
declare -a PROJECTS_NOT_DELETED_LIST
declare -a PROJECTS_NOT_DELETED_REASONS

################################################################################
# Function: print_usage
# Description: Display script usage information
################################################################################
print_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Project Cleanup Script for webMethods.io Integration

OPTIONS:
    -u, --url URL               webMethods.io tenant URL (required)
    -n, --username USERNAME     Username — CA3S auth credential; also the ownership
                                transfer target in MCSP environments (required for both)
    -p, --password PASSWORD     Password for authentication (CA3S only)
    -k, --api-key KEY           Instance API Key for MCSP authentication
    -a, --app-env ENV           Application environment (e.g., "mcsp", "ca3s")
    -e, --exception-list FILE   Exception list JSON file (default: DefaultExceptionList.json)
    -x, --prefixes PREFIXES     Comma-separated project prefixes to exclude (default: Auto_,Man_,BVT_)
                                Use "Null" to skip prefix filtering
    -t, --timeout SECONDS       Request timeout in seconds (default: 180)
    -d, --dry-run               Perform a dry run without deleting projects
    -h, --help                  Display this help message

ENVIRONMENT VARIABLES:
    WMIO_TENANT_URL             webMethods.io tenant URL
    WMIO_USERNAME               Username for CA3S authentication; also used as the
                                ownership transfer target before deletion in MCSP
    WMIO_PASSWORD               Password for CA3S authentication
    APP_ENV                     Application environment (mcsp/ca3s)
    INSTANCE_API_KEY            Instance API Key for MCSP
    EXCEPTION_LIST_FILE         Exception list JSON file name
    PROJECT_PREFIX_NAMES        Comma-separated project prefixes
    DRY_RUN                     Set to "true" for dry run mode
    REQUEST_TIMEOUT             Request timeout in seconds

AUTHENTICATION:
    CA3S (Basic Auth):
        $0 -u "https://tenant.webmethods.io" -n "user" -p "pass" -a "ca3s"
    
    MCSP (API Key):
        $0 -u "https://tenant.webmethods.io" -k "your-api-key" -a "mcsp"

EXAMPLES:
    # CA3S environment with basic auth
    $0 -u "https://tenant.webmethods.io" -n "siqaauto" -p "password" -a "ca3s"

    # MCSP environment with API key
    $0 -u "https://tenant.webmethods.io" -k "abc123xyz" -a "mcsp"

    # Using environment variables
    export WMIO_TENANT_URL="https://tenant.webmethods.io"
    export WMIO_USERNAME="siqaauto"
    export WMIO_PASSWORD="password"
    export APP_ENV="ca3s"
    $0

    # Dry run mode
    $0 -u "https://tenant.webmethods.io" -n "user" -p "pass" -a "ca3s" -d

    # Custom exception list and prefixes
    $0 -u "https://tenant.webmethods.io" -n "user" -p "pass" -a "ca3s" \\
       -e "devRealm1exceptionProjectsList.json" -x "SIQA_,Test_"

EXCEPTION LIST FORMAT:
    The exception list should be a JSON file with the following structure:
    {
      "projects": [
        "ProjectName1",
        "ProjectName2",
        "ProjectName3"
      ]
    }

EOF
}

################################################################################
# Function: log_info
# Description: Print informational message
################################################################################
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

################################################################################
# Function: log_success
# Description: Print success message
################################################################################
log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

################################################################################
# Function: log_warning
# Description: Print warning message
################################################################################
log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

################################################################################
# Function: log_error
# Description: Print error message
################################################################################
log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

################################################################################
# Function: fetch_mcsp_tokens
# Description: Exchange the INSTANCE_API_KEY for session tokens required by
#              enterprise APIs (authtoken, cookie, x-csrf-token).
#              Results are cached in MCSP_AUTHTOKEN / MCSP_COOKIE / MCSP_CSRF.
#              GET <url>/enterprise/v1/user/token
################################################################################
fetch_mcsp_tokens() {
    if [ -n "$MCSP_AUTHTOKEN" ]; then
        return 0  # already fetched
    fi

    local token_url="${WMIO_TENANT_URL}/enterprise/v1/user/token"

    log_info "Fetching MCSP session tokens from: ${token_url}" >&2

    local response
    response=$(curl -s -w "\n%{http_code}" -X GET \
        -H "X-INSTANCE-API-KEY: ${INSTANCE_API_KEY}" \
        -H "Content-Type: application/json" \
        --max-time "$REQUEST_TIMEOUT" \
        "$token_url")
    local curl_exit=$?

    local http_code
    http_code=$(echo "$response" | tail -n1)
    local body
    body=$(echo "$response" | sed '$d')

    log_info "DEBUG [fetch_mcsp_tokens] curl exit: ${curl_exit} | HTTP: ${http_code}" >&2
    log_info "DEBUG [fetch_mcsp_tokens] body: ${body}" >&2

    if [ $curl_exit -ne 0 ]; then
        log_error "curl failed (exit ${curl_exit}) while fetching MCSP tokens"
        exit 1
    fi

    if [ "$http_code" != "200" ]; then
        log_error "Failed to fetch MCSP tokens - HTTP ${http_code}: ${body}"
        exit 1
    fi

    MCSP_AUTHTOKEN=$(echo "$body" | jq -r '.output.authtoken // empty')
    MCSP_COOKIE=$(echo "$body"    | jq -r '.output.cookie    // empty')
    MCSP_CSRF=$(echo "$body"      | jq -r '.output.csrf      // empty')

    if [ -z "$MCSP_AUTHTOKEN" ] || [ -z "$MCSP_COOKIE" ] || [ -z "$MCSP_CSRF" ]; then
        log_error "MCSP token response missing one or more fields (authtoken/cookie/csrf)"
        log_error "Response: ${body}"
        exit 1
    fi

    log_success "MCSP session tokens fetched successfully" >&2
}

################################################################################
# Function: set_auth_headers
# Description: Set authentication headers based on environment (CA3S or MCSP)
# Returns: Authentication header string for curl
################################################################################
set_auth_headers() {
    local auth_header=""
    
    # Check if MCSP environment
    if [[ "${APP_ENV,,}" == *"mcsp"* ]]; then
        if [ -z "$INSTANCE_API_KEY" ]; then
            log_error "MCSP environment requires INSTANCE_API_KEY"
            exit 1
        fi
        auth_header="-H \"X-INSTANCE-API-KEY: ${INSTANCE_API_KEY}\""
        log_info "Using MCSP authentication (API Key)" >&2
    else
        # CA3S - Basic Auth
        if [ -z "$WMIO_USERNAME" ] || [ -z "$WMIO_PASSWORD" ]; then
            log_error "CA3S environment requires USERNAME and PASSWORD"
            exit 1
        fi
        auth_header="-u \"${WMIO_USERNAME}:${WMIO_PASSWORD}\""
        log_info "Using CA3S authentication (Basic Auth)" >&2
    fi
    
    echo "$auth_header"
}

################################################################################
# Function: get_project_id
# Description: Get project ID by project name
# Arguments:
#   $1 - Tenant URL
#   $2 - Project Name
# Returns: Project UID or empty string
################################################################################
get_project_id() {
    local url="$1"
    local project_name="$2"
    local auth_header=$(set_auth_headers)
    
    local response=$(eval curl -s -w \"\\n%{http_code}\" -X GET \
        $auth_header \
        -H \"Content-Type: application/json\" \
        --max-time \"$REQUEST_TIMEOUT\" \
        \"${url}/apis/v1/rest/projects/${project_name}\")
    
    if [ $? -ne 0 ]; then
        log_error "Failed to get project ID for: $project_name - curl failed" >&2
        return 1
    fi
    
    # Extract HTTP code and body
    local http_code=$(echo "$response" | tail -n1)
    local body=$(echo "$response" | sed '$d')
    
    # Check HTTP status
    if [ "$http_code" != "200" ]; then
        log_error "Failed to get project ID for: $project_name - HTTP $http_code" >&2
        return 1
    fi
    
    local project_id=$(echo "$body" | jq -r '.output.uid // empty' 2>/dev/null)
    echo "$project_id"
}

################################################################################
# Function: get_all_projects
# Description: Retrieve all projects from the tenant
# Arguments:
#   $1 - Tenant URL
# Returns: JSON array of projects
################################################################################
get_all_projects() {
    local url="$1"
    local auth_header=$(set_auth_headers)
    
    log_info "Fetching all projects from tenant..." >&2
    
    # Debug: Show the curl command being executed
    log_info "DEBUG: curl command: curl -s -w \"\\n%{http_code}\" -X GET $auth_header -H \"Content-Type: application/json\" --max-time \"$REQUEST_TIMEOUT\" \"${url}/apis/v1/rest/projects\"" >&2
    
    local response=$(eval curl -s -w \"\\n%{http_code}\" -X GET \
        $auth_header \
        -H \"Content-Type: application/json\" \
        --max-time \"$REQUEST_TIMEOUT\" \
        \"${url}/apis/v1/rest/projects\")
    
    local curl_exit=$?
    
    # Debug: Show raw response
    log_info "DEBUG: curl exit code: $curl_exit" >&2
    log_info "DEBUG: raw response length: ${#response}" >&2
    log_info "DEBUG: raw response (first 500 chars): ${response:0:500}" >&2
    
    if [ $curl_exit -ne 0 ]; then
        log_error "Failed to fetch projects - curl command failed with exit code $curl_exit"
        exit 1
    fi
    
    # Extract HTTP code and body
    local http_code=$(echo "$response" | tail -n1)
    local body=$(echo "$response" | sed '$d')
    
    log_info "DEBUG: HTTP code: $http_code" >&2
    log_info "DEBUG: body length: ${#body}" >&2
    log_info "DEBUG: body (first 200 chars): ${body:0:200}" >&2
    
    # Check HTTP status
    if [ "$http_code" != "200" ]; then
        log_error "Failed to fetch projects - HTTP $http_code"
        log_error "Response: $body"
        exit 1
    fi
    
    # Validate JSON response
    log_info "DEBUG: Validating JSON with jq..." >&2
    local jq_test=$(echo "$body" | jq empty 2>&1)
    local jq_exit=$?
    log_info "DEBUG: jq validation exit code: $jq_exit" >&2
    log_info "DEBUG: jq validation output: $jq_test" >&2
    
    if [ $jq_exit -ne 0 ]; then
        log_error "Invalid JSON response from API"
        log_error "jq error: $jq_test"
        log_error "Response (first 1000 chars): ${body:0:1000}"
        exit 1
    fi
    
    log_info "DEBUG: JSON validation passed, returning body" >&2
    echo "$body"
}

################################################################################
# Function: transfer_project_ownership
# Description: Transfer project ownership to WMIO_USERNAME (MCSP only).
#              Called before deletion so the API key user owns the project.
# Arguments:
#   $1 - Tenant URL
#   $2 - Project ID
#   $3 - Project Name (for logging)
# Returns: 0 on success, 1 on failure
################################################################################
transfer_project_ownership() {
    local url="$1"
    local project_id="$2"
    local project_name="$3"

    log_info "Transferring ownership of project: $project_name (ID: $project_id) to user: $WMIO_USERNAME"

    # Ensure we have valid session tokens (fetched once, cached globally)
    fetch_mcsp_tokens

    local payload
    payload=$(jq -n --arg user "$WMIO_USERNAME" \
        '{"keepPreviousOwnerAsCollaborator": false, "username": $user}')

    local response
    response=$(curl -s -w "\n%{http_code}" -X PUT \
        -H "Content-Type: application/json" \
        -H "authtoken: ${MCSP_AUTHTOKEN}" \
        -H "x-csrf-token: ${MCSP_CSRF}" \
        -H "Cookie: ${MCSP_COOKIE}" \
        -d "$payload" \
        --max-time "$REQUEST_TIMEOUT" \
        "${url}/enterprise/v1/projects/${project_id}/ownership")

    local http_code
    http_code=$(echo "$response" | tail -n1)
    local body
    body=$(echo "$response" | sed '$d')

    if [ "$http_code" = "200" ] || [ "$http_code" = "204" ]; then
        log_success "Ownership transferred successfully for project: $project_name"
        return 0
    else
        local error_msg
        error_msg=$(echo "$body" | jq -r '.error.message // .message // "Unknown error"' 2>/dev/null)
        log_error "Failed to transfer ownership for project: $project_name - HTTP $http_code - $error_msg"
        return 1
    fi
}

################################################################################
# Function: delete_project_permanent
# Description: Permanently delete a project by name.
#              In MCSP environments, ownership is transferred to WMIO_USERNAME
#              before deletion.
# Arguments:
#   $1 - Tenant URL
#   $2 - Project Name
# Returns: 0 on success, 1 on failure
################################################################################
delete_project_permanent() {
    local url="$1"
    local project_name="$2"

    # Get project ID first
    local project_id=$(get_project_id "$url" "$project_name")

    if [ -z "$project_id" ]; then
        log_error "Failed to get project ID for: $project_name (project may not exist)"
        PROJECTS_NOT_DELETED_LIST+=("$project_name")
        PROJECTS_NOT_DELETED_REASONS+=("Project not found or failed to retrieve project ID")
        ((PROJECTS_NOT_DELETED++))
        return 1
    fi

    if [ "$DRY_RUN" = "true" ]; then
        if [[ "${APP_ENV,,}" == *"mcsp"* ]]; then
            log_info "[DRY RUN] Would transfer ownership of project: $project_name (ID: $project_id) to user: $WMIO_USERNAME"
        fi
        log_info "[DRY RUN] Would delete project: $project_name (ID: $project_id)"
        return 0
    fi

    # MCSP: transfer ownership before deletion (best-effort — proceed even if it fails)
    if [[ "${APP_ENV,,}" == *"mcsp"* ]]; then
        if ! transfer_project_ownership "$url" "$project_id" "$project_name"; then
            log_warning "Ownership transfer failed for: $project_name — attempting deletion anyway"
        fi
    fi

    log_info "Deleting project: $project_name (ID: $project_id)"

    local auth_header=$(set_auth_headers)
    
    # Construct payload matching Java implementation
    local payload=$(jq -n \
        --arg name "$project_name" \
        '{force_delete: true, confirm_project_name: ("Delete " + $name)}')
    
    local response=$(eval curl -s -w \"\\n%{http_code}\" -X DELETE \
        $auth_header \
        -H \"Content-Type: application/json\" \
        -d \'$payload\' \
        --max-time \"$REQUEST_TIMEOUT\" \
        \"${url}/apis/v1/rest/projects/${project_id}\")
    
    local http_code=$(echo "$response" | tail -n1)
    local body=$(echo "$response" | sed '$d')
    
    if [ "$http_code" = "200" ]; then
        log_success "Project deleted successfully: $project_name"
        return 0
    else
        local error_msg=$(echo "$body" | jq -r '.error.message // "Unknown error"')
        log_error "Failed to delete project: $project_name - HTTP $http_code - $error_msg"
        PROJECTS_NOT_DELETED_LIST+=("$project_name")
        PROJECTS_NOT_DELETED_REASONS+=("HTTP $http_code: $error_msg")
        ((PROJECTS_NOT_DELETED++))
        return 1
    fi
}

################################################################################
# Function: load_exception_list
# Description: Load exception list from JSON file
# Arguments:
#   $1 - Exception list file path
# Returns: JSON array of project names
################################################################################
load_exception_list() {
    local file_path="$1"
    
    if [ ! -f "$file_path" ]; then
        log_error "Exception list file not found: $file_path"
        exit 1
    fi
    
    log_info "Loading exception list from: $file_path"
    
    local projects=$(jq -r '.projects[]' "$file_path")
    
    if [ -z "$projects" ]; then
        log_error "Failed to parse exception list or list is empty"
        exit 1
    fi
    
    REQUIRED_PROJECTS=$(echo "$projects" | wc -l)
    log_info "Loaded $REQUIRED_PROJECTS projects from exception list"
    
    echo "$projects"
}

################################################################################
# Function: cleanup_projects
# Description: Main cleanup logic
################################################################################
cleanup_projects() {
    log_info "Starting project cleanup process..."
    log_info "Tenant URL: $WMIO_TENANT_URL"
    log_info "Environment: $APP_ENV"
    log_info "Exception List: $EXCEPTION_LIST_FILE"
    log_info "Project Prefixes: $PROJECT_PREFIX_NAMES"
    log_info "Request Timeout: ${REQUEST_TIMEOUT}s"
    
    if [ "$DRY_RUN" = "true" ]; then
        log_warning "DRY RUN MODE - No projects will be deleted"
    fi
    
    echo ""
    log_info "=========================================="
    
    # Load exception list
    local exception_list_path="${EXCEPTION_LIST_DIR}/${EXCEPTION_LIST_FILE}"
    local exception_projects=$(load_exception_list "$exception_list_path")
    
    # Get all projects
    local all_projects_response=$(get_all_projects "$WMIO_TENANT_URL")
    log_info "DEBUG: all_projects_response length: ${#all_projects_response}" >&2
    log_info "DEBUG: all_projects_response (first 300 chars): ${all_projects_response:0:300}" >&2
    
    local all_projects=$(echo "$all_projects_response" | jq '.output.projects' 2>&1)
    local jq_exit=$?
    log_info "DEBUG: jq '.output.projects' exit code: $jq_exit" >&2
    log_info "DEBUG: all_projects length: ${#all_projects}" >&2
    log_info "DEBUG: all_projects (first 300 chars): ${all_projects:0:300}" >&2
    
    PROJECTS_BEFORE_CLEANUP=$(echo "$all_projects" | jq 'length' 2>&1 || echo "0")
    log_info "DEBUG: Project count calculation result: $PROJECTS_BEFORE_CLEANUP" >&2
    log_info "Number of projects in tenant before cleanup: $PROJECTS_BEFORE_CLEANUP"
    
    # Filter projects - remove exception list projects
    log_info "Filtering projects based on exception list..."
    local projects_to_process="$all_projects"
    
    while IFS= read -r exception_project; do
        projects_to_process=$(echo "$projects_to_process" | jq --arg name "$exception_project" '[.[] | select(.name != $name)]')
    done <<< "$exception_projects"
    
    # Filter by prefixes if not "Null"
    if [ "$PROJECT_PREFIX_NAMES" != "Null" ]; then
        log_info "Filtering projects based on prefixes..."
        IFS=',' read -ra PREFIXES <<< "$PROJECT_PREFIX_NAMES"
        
        for prefix in "${PREFIXES[@]}"; do
            prefix=$(echo "$prefix" | xargs)  # Trim whitespace
            log_info "Excluding projects starting with: $prefix"
            projects_to_process=$(echo "$projects_to_process" | jq --arg prefix "$prefix" '[.[] | select(.name | startswith($prefix) | not)]')
        done
    else
        log_info "Skipping prefix filtering (set to Null)"
    fi
    
    local projects_to_delete_count=$(echo "$projects_to_process" | jq 'length')
    log_info "Projects to delete: $projects_to_delete_count"
    
    echo ""
    log_info "=========================================="
    log_info "Starting deletion process..."
    echo ""
    
    # Delete projects
    local deleted_count=0
    while IFS= read -r project; do
        local project_name=$(echo "$project" | jq -r '.name')
        
        if delete_project_permanent "$WMIO_TENANT_URL" "$project_name"; then
            ((deleted_count++))
        fi
        
        # Small delay to avoid rate limiting
        sleep 0.5
    done < <(echo "$projects_to_process" | jq -c '.[]')
    
    # Get final project count
    local final_projects_response=$(get_all_projects "$WMIO_TENANT_URL")
    PROJECTS_AFTER_CLEANUP=$(echo "$final_projects_response" | jq -r '.output.projects | length')
    
    echo ""
    log_info "=========================================="
    log_info "Cleanup Summary:"
    log_info "  Required projects (exception list): $REQUIRED_PROJECTS"
    log_info "  Projects before cleanup: $PROJECTS_BEFORE_CLEANUP"
    log_info "  Projects after cleanup: $PROJECTS_AFTER_CLEANUP"
    log_info "  Projects successfully deleted: $deleted_count"
    log_info "  Projects failed to delete: $PROJECTS_NOT_DELETED"
    
    if [ $PROJECTS_NOT_DELETED -gt 0 ]; then
        log_warning "Projects that could not be deleted:"
        for i in "${!PROJECTS_NOT_DELETED_LIST[@]}"; do
            log_warning "  - ${PROJECTS_NOT_DELETED_LIST[$i]}: ${PROJECTS_NOT_DELETED_REASONS[$i]}"
        done
    fi
    log_info "=========================================="
    
    log_success "Project cleanup completed!"
}

################################################################################
# Main Script Execution
################################################################################

# Main function to wrap execution and prevent shell logout
main() {
    # Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -u|--url)
            WMIO_TENANT_URL="$2"
            shift 2
            ;;
        -n|--username)
            WMIO_USERNAME="$2"
            shift 2
            ;;
        -p|--password)
            WMIO_PASSWORD="$2"
            shift 2
            ;;
        -k|--api-key)
            INSTANCE_API_KEY="$2"
            shift 2
            ;;
        -a|--app-env)
            APP_ENV="$2"
            shift 2
            ;;
        -e|--exception-list)
            EXCEPTION_LIST_FILE="$2"
            shift 2
            ;;
        -x|--prefixes)
            PROJECT_PREFIX_NAMES="$2"
            shift 2
            ;;
        -t|--timeout)
            REQUEST_TIMEOUT="$2"
            shift 2
            ;;
        -d|--dry-run)
            DRY_RUN="true"
            shift
            ;;
        -h|--help)
            print_usage
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            print_usage
            exit 1
            ;;
    esac
done

# Validate required parameters
if [ -z "$WMIO_TENANT_URL" ]; then
    log_error "Missing required parameter: WMIO_TENANT_URL"
    echo ""
    print_usage
    exit 1
fi

if [ -z "$APP_ENV" ]; then
    log_error "Missing required parameter: APP_ENV (ca3s or mcsp)"
    echo ""
    print_usage
    exit 1
fi

# Validate authentication based on environment
if [[ "${APP_ENV,,}" == *"mcsp"* ]]; then
    if [ -z "$INSTANCE_API_KEY" ]; then
        log_error "MCSP environment requires INSTANCE_API_KEY"
        echo ""
        print_usage
        exit 1
    fi
    if [ -z "$WMIO_USERNAME" ]; then
        log_error "MCSP environment requires USERNAME (-n/--username) for ownership transfer before deletion"
        echo ""
        print_usage
        exit 1
    fi
else
    if [ -z "$WMIO_USERNAME" ] || [ -z "$WMIO_PASSWORD" ]; then
        log_error "CA3S environment requires USERNAME and PASSWORD"
        echo ""
        print_usage
        exit 1
    fi
fi

# Check for required tools
if ! command -v jq &> /dev/null; then
    log_error "jq is required but not installed. Please install jq to continue."
    exit 1
fi

if ! command -v curl &> /dev/null; then
    log_error "curl is required but not installed. Please install curl to continue."
    exit 1
fi

# Create exception lists directory if it doesn't exist
mkdir -p "$EXCEPTION_LIST_DIR"

    # Run cleanup
    cleanup_projects
    
    return 0
}

# Execute main function only if script is run directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
    exit $?
fi

# Made with Bob

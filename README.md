# Project Cleanup Shell Script

This standalone shell script automates the cleanup of projects in webMethods.io Integration tenants based on exception lists and project prefix filters. It's designed to work independently without any framework dependencies.

## Features

- ✅ **Dual Authentication Support**: Works with both CA3S (Basic Auth) and MCSP (API Key) environments
- ✅ **Exception Lists**: Protects specific projects from deletion using JSON configuration files ([Exception List](https://ibm-middleware.atlassian.net/wiki/spaces/RNDWCLOUD/pages/1809973332/IWHI+Integration+Project+Information+Team+wise)(case-sensitive))
- ✅ **Prefix Filtering**: Excludes projects based on name prefixes (e.g., `Auto_`, `SIQA_`, `Test_`)
- ✅ **Dry Run Mode**: Preview what would be deleted without actually deleting
- ✅ **Detailed Logging**: Color-coded output with comprehensive status reporting
- ✅ **Error Handling**: Tracks and reports projects that couldn't be deleted
- ✅ **Configurable Timeout**: Adjustable request timeout for large operations
- ✅ **Standalone**: No framework dependencies required (Legacy: [Legacy Code](https://github.com/ibm-webmethods/siqa-cloud-automation/blob/yada_ProjectCleanup/src/test/resources/Features/ProjectCleanup/ProjectCleanup.feature))

## Prerequisites

### Required Tools

1. **bash** - Shell interpreter (pre-installed on Linux/Mac, use Git Bash on Windows)
2. **curl** - HTTP client for API calls
3. **jq** - JSON processor for parsing responses

#### Installing jq

**Linux (Ubuntu/Debian):**
```bash
sudo apt-get install jq
```

**macOS:**
```bash
brew install jq
```

**Windows:**
Download from https://stedolan.github.io/jq/download/ or use:
```bash
choco install jq
```

## Directory Structure

```
project-cleanup/
├── project_cleanup.sh              # Main cleanup script
├── README_PROJECT_CLEANUP.md       # This file
└── exception_lists/                # Exception list JSON files
    ├── DefaultExceptionList.json
    └── devRealm1exceptionProjectsList.json
```

## Exception List Format

Exception lists are JSON files that specify which projects should NOT be deleted:

```json
{
  "projects": [
    "ProjectName1",
    "ProjectName2",
    "SIQA_E2E_Automation",
    "Default"
  ]
}
```

### Available Exception Lists

1. **DefaultExceptionList.json** - Standard exception list for most environments
2. **devRealm1exceptionProjectsList.json** - Exception list for devRealm1 environment

You can create custom exception lists by adding new JSON files to the `exception_lists/` directory.

## Usage

### Basic Syntax

```bash
./project_cleanup.sh [OPTIONS]
```

### Authentication Methods

#### CA3S Environment (Basic Auth)

```bash
./project_cleanup.sh \
  -u "https://tenant.webmethods.io" \
  -n "username" \
  -p "password" \
  -a "ca3s"
```

#### MCSP Environment (API Key)

```bash
./project_cleanup.sh \
  -u "https://tenant.webmethods.io" \
  -k "your-instance-api-key" \
  -a "mcsp"
```

### Command Line Options

| Option | Long Form | Description | Required |
|--------|-----------|-------------|----------|
| `-u` | `--url` | webMethods.io tenant URL | Yes |
| `-n` | `--username` | Username (CA3S only) | Yes (MCSP: For project ownership change before deletion, username and API Key should match for successful cleanup) |
| `-p` | `--password` | Password (CA3S only) | CA3S only |
| `-k` | `--api-key` | Instance API Key (MCSP only) | MCSP only |
| `-a` | `--app-env` | Environment type (ca3s/mcsp) | Yes |
| `-e` | `--exception-list` | Exception list filename | No (default: DefaultExceptionList.json) |
| `-x` | `--prefixes` | Project prefixes to exclude | No (default: Auto_,Man_,BVT_) |
| `-t` | `--timeout` | Request timeout in seconds | No (default: 180) |
| `-d` | `--dry-run` | Preview mode (no deletion) | No |
| `-h` | `--help` | Show help message | No |

### Environment Variables

You can also configure the script using environment variables:

```bash
export WMIO_TENANT_URL="https://tenant.webmethods.io"
export WMIO_USERNAME="siqaauto"
export WMIO_PASSWORD="password"
export APP_ENV="ca3s"
export EXCEPTION_LIST_FILE="DefaultExceptionList.json"
export PROJECT_PREFIX_NAMES="Auto_,Man_,BVT_"
export DRY_RUN="false"
export REQUEST_TIMEOUT="180"

./project_cleanup.sh
```

## Examples

### Example 1: Dry Run (Preview Mode)

Preview what would be deleted without actually deleting:

```bash
./project_cleanup.sh \
  -u "https://originawsdev1.dev-int-aws-us.webmethods.io" \
  -n "siqaauto" \
  -p "Siqasecrets@2023" \
  -a "ca3s" \
  -d
```

### Example 2: Standard Cleanup with Default Settings

```bash
./project_cleanup.sh \
  -u "https://originawsdev1.dev-int-aws-us.webmethods.io" \
  -n "siqaauto" \
  -p "Siqasecrets@2023" \
  -a "ca3s"
```

### Example 3: Custom Exception List

```bash
./project_cleanup.sh \
  -u "https://tenant.webmethods.io" \
  -n "siqaauto" \
  -p "password" \
  -a "ca3s" \
  -e "devRealm1exceptionProjectsList.json"
```

### Example 4: Custom Prefix Filtering

Exclude projects starting with `SIQA_` or `Test_`:

```bash
./project_cleanup.sh \
  -u "https://tenant.webmethods.io" \
  -n "siqaauto" \
  -p "password" \
  -a "ca3s" \
  -x "SIQA_,Test_"
```

### Example 5: Skip Prefix Filtering

Use `"Null"` to skip prefix filtering entirely:

```bash
./project_cleanup.sh \
  -u "https://tenant.webmethods.io" \
  -n "siqaauto" \
  -p "password" \
  -a "ca3s" \
  -x "Null"
```

### Example 6: MCSP Environment

```bash
./project_cleanup.sh \
  -u "https://mcsp-tenant.webmethods.io" \
  -k "abc123xyz456" \
  -a "mcsp"
```

### Example 7: Increased Timeout for Large Tenants

```bash
./project_cleanup.sh \
  -u "https://tenant.webmethods.io" \
  -n "siqaauto" \
  -p "password" \
  -a "ca3s" \
  -t 300
```

## Output

The script provides color-coded output:

- 🔵 **BLUE** - Informational messages
- 🟢 **GREEN** - Success messages
- 🟡 **YELLOW** - Warnings
- 🔴 **RED** - Errors

### Sample Output

```
[INFO] Starting project cleanup process...
[INFO] Tenant URL: https://originawsdev1.dev-int-aws-us.webmethods.io
[INFO] Environment: ca3s
[INFO] Exception List: DefaultExceptionList.json
[INFO] Project Prefixes: Auto_,Man_,BVT_
[INFO] Request Timeout: 180s
[INFO] ==========================================
[INFO] Using CA3S authentication (Basic Auth)
[INFO] Loading exception list from: ./exception_lists/DefaultExceptionList.json
[INFO] Loaded 94 projects from exception list
[INFO] Fetching all projects from tenant...
[INFO] Number of projects in tenant before cleanup: 150
[INFO] Filtering projects based on exception list...
[INFO] Filtering projects based on prefixes...
[INFO] Excluding projects starting with: Auto_
[INFO] Excluding projects starting with: Man_
[INFO] Excluding projects starting with: BVT_
[INFO] Projects to delete: 25
[INFO] ==========================================
[INFO] Starting deletion process...

[INFO] Deleting project: TestProject1 (ID: abc123)
[SUCCESS] Project deleted successfully: TestProject1
[INFO] Deleting project: TestProject2 (ID: def456)
[SUCCESS] Project deleted successfully: TestProject2
...

[INFO] ==========================================
[INFO] Cleanup Summary:
[INFO]   Required projects (exception list): 94
[INFO]   Projects before cleanup: 150
[INFO]   Projects after cleanup: 125
[INFO]   Projects successfully deleted: 25
[INFO]   Projects failed to delete: 0
[INFO] ==========================================
[SUCCESS] Project cleanup completed!
```

## How It Works

1. **Authentication**: Authenticates with the tenant using either Basic Auth (CA3S) or API Key (MCSP)
2. **Load Exception List**: Reads the specified JSON file containing projects to protect
3. **Fetch Projects**: Retrieves all projects from the tenant
4. **Filter Projects**: 
   - Removes projects in the exception list
   - Removes projects matching specified prefixes
5. **Delete Projects**: Iterates through remaining projects and deletes them using force delete
6. **Report Results**: Displays summary with success/failure counts

## Troubleshooting

### Issue: Script logs me out of the VM / Shell exits unexpectedly

**Cause**: This can happen if the script encounters an error during execution.

**Solution**:
1. Make sure the script is executable: `chmod +x project_cleanup.sh`
2. Run the script directly (not sourced): `./project_cleanup.sh [options]`
3. Do NOT run with `source` or `.` command: ~~`source project_cleanup.sh`~~ ❌
4. Check that all required tools are installed (jq, curl)
5. Verify your credentials and parameters are correct
6. Run in dry-run mode first to test: `./project_cleanup.sh -u "..." -n "..." -p "..." -a "ca3s" -d`

### Issue: "jq: command not found"

**Solution**: Install jq using the instructions in the Prerequisites section.

### Issue: "curl: command not found"

**Solution**: Install curl:
- Linux: `sudo apt-get install curl`
- macOS: Pre-installed
- Windows: Use Git Bash or install from https://curl.se/

### Issue: "Failed to authenticate with tenant"

**Solution**: 
- Verify your credentials are correct
- Check that the tenant URL is accessible
- Ensure you're using the correct authentication method (CA3S vs MCSP)

### Issue: "Exception list file not found"

**Solution**: 
- Verify the exception list file exists in the `exception_lists/` directory
- Check the filename spelling
- Use the `-e` option to specify the correct filename

### Issue: "Failed to delete project"

**Possible Causes**:
- Project contains workflows or flowservices (script uses force delete by default)
- Insufficient permissions
- Project is locked or in use
- Network timeout

**Solution**: The script uses `force_delete: true` by default. Check the error message for specific details.

## Best Practices

1. **Always run in dry-run mode first** to preview what will be deleted:
   ```bash
   ./project_cleanup.sh -u "..." -n "..." -p "..." -a "ca3s" -d
   ```

2. **Maintain separate exception lists** for different environments (dev, test, prod)

3. **Use descriptive project prefixes** to easily identify and protect project groups

4. **Review exception lists regularly** to ensure they're up to date

5. **Run during off-peak hours** to minimize impact on active users

6. **Keep logs** of cleanup operations for audit purposes:
   ```bash
   ./project_cleanup.sh ... 2>&1 | tee cleanup_$(date +%Y%m%d_%H%M%S).log
   ```

## Security Considerations

- **Never commit credentials** to version control
- Use environment variables for sensitive data
- Restrict script execution permissions: `chmod 700 project_cleanup.sh`
- Audit exception lists to prevent accidental deletion of critical projects
- Consider using a service account with limited permissions

## Making the Script Executable

On Linux/Mac:
```bash
chmod +x project_cleanup.sh
```

On Windows (Git Bash):
```bash
# No need to change permissions, just run with bash
bash project_cleanup.sh [OPTIONS]
```

## License

This is a standalone utility script for webMethods.io Integration project cleanup.

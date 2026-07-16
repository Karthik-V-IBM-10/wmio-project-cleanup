#!/bin/bash

################################################################################
# Example Usage Script for Project Cleanup
# 
# This script demonstrates different ways to use the project_cleanup.sh script
################################################################################

echo "=========================================="
echo "Project Cleanup - Example Usage"
echo "=========================================="
echo ""

# Example 1: Dry Run with CA3S Authentication
echo "Example 1: Dry Run (Preview Mode) - CA3S"
echo "Command:"
echo "./project_cleanup.sh \\"
echo "  -u \"https://originawsdev1.dev-int-aws-us.webmethods.io\" \\"
echo "  -n \"siqaauto\" \\"
echo "  -p \"Siqasecrets@2023\" \\"
echo "  -a \"ca3s\" \\"
echo "  -d"
echo ""
echo "This will show what would be deleted without actually deleting anything."
echo ""
echo "=========================================="
echo ""

# Example 2: Actual Cleanup with Default Settings
echo "Example 2: Standard Cleanup - CA3S"
echo "Command:"
echo "./project_cleanup.sh \\"
echo "  -u \"https://originawsdev1.dev-int-aws-us.webmethods.io\" \\"
echo "  -n \"siqaauto\" \\"
echo "  -p \"Siqasecrets@2023\" \\"
echo "  -a \"ca3s\""
echo ""
echo "This will delete projects using default exception list and prefixes."
echo ""
echo "=========================================="
echo ""

# Example 3: MCSP Environment
echo "Example 3: MCSP Environment with API Key"
echo "Command:"
echo "./project_cleanup.sh \\"
echo "  -u \"https://mcsp-tenant.webmethods.io\" \\"
echo "  -k \"your-instance-api-key\" \\"
echo "  -a \"mcsp\""
echo ""
echo "This uses API Key authentication for MCSP environments."
echo ""
echo "=========================================="
echo ""

# Example 4: Custom Exception List
echo "Example 4: Custom Exception List"
echo "Command:"
echo "./project_cleanup.sh \\"
echo "  -u \"https://tenant.webmethods.io\" \\"
echo "  -n \"siqaauto\" \\"
echo "  -p \"password\" \\"
echo "  -a \"ca3s\" \\"
echo "  -e \"devRealm1exceptionProjectsList.json\""
echo ""
echo "This uses a custom exception list file."
echo ""
echo "=========================================="
echo ""

# Example 5: Custom Prefixes
echo "Example 5: Custom Project Prefixes"
echo "Command:"
echo "./project_cleanup.sh \\"
echo "  -u \"https://tenant.webmethods.io\" \\"
echo "  -n \"siqaauto\" \\"
echo "  -p \"password\" \\"
echo "  -a \"ca3s\" \\"
echo "  -x \"SIQA_,Test_,Demo_\""
echo ""
echo "This excludes projects starting with SIQA_, Test_, or Demo_."
echo ""
echo "=========================================="
echo ""

# Example 6: Using Environment Variables
echo "Example 6: Using Environment Variables"
echo "Commands:"
echo "export WMIO_TENANT_URL=\"https://tenant.webmethods.io\""
echo "export WMIO_USERNAME=\"siqaauto\""
echo "export WMIO_PASSWORD=\"password\""
echo "export APP_ENV=\"ca3s\""
echo "export DRY_RUN=\"true\""
echo "./project_cleanup.sh"
echo ""
echo "This uses environment variables instead of command line arguments."
echo ""
echo "=========================================="
echo ""

# Example 7: With Logging
echo "Example 7: With Logging to File"
echo "Command:"
echo "./project_cleanup.sh \\"
echo "  -u \"https://tenant.webmethods.io\" \\"
echo "  -n \"siqaauto\" \\"
echo "  -p \"password\" \\"
echo "  -a \"ca3s\" \\"
echo "  2>&1 | tee cleanup_\$(date +%Y%m%d_%H%M%S).log"
echo ""
echo "This saves the output to a timestamped log file."
echo ""
echo "=========================================="
echo ""

echo "To run any of these examples, copy the command and replace the"
echo "placeholder values with your actual credentials and URLs."
echo ""
echo "IMPORTANT: Always run with -d (dry-run) flag first to preview!"

# Made with Bob

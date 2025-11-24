#!/bin/bash

# Deploy Lambda Functions Script
# This script packages and deploys all Lambda functions to AWS
# Usage: ./deploy-lambdas.sh [environment] [function-name]
#
# Examples:
#   ./deploy-lambdas.sh dev                    # Deploy all functions to dev
#   ./deploy-lambdas.sh prod                   # Deploy all functions to prod
#   ./deploy-lambdas.sh dev sam-json-processor # Deploy single function

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Parse arguments
ENVIRONMENT=${1:-dev}
SINGLE_FUNCTION=${2:-""}
REGION=${AWS_REGION:-us-east-1}

# Define all Lambda functions
LAMBDA_FUNCTIONS=(
    "sam-gov-daily-download"
    "sam-json-processor"
    "sam-sqs-generate-match-reports"
    "sam-daily-email-notification"
    "sam-email-notification"
    "sam-merge-and-archive-result-logs"
    "sam-produce-user-report"
    "sam-produce-web-reports"
)

# If single function specified, deploy only that one
if [ -n "$SINGLE_FUNCTION" ]; then
    LAMBDA_FUNCTIONS=("$SINGLE_FUNCTION")
fi

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI not found. Install it first: https://aws.amazon.com/cli/"
        exit 1
    fi
    
    if ! command -v python3 &> /dev/null; then
        log_error "Python 3 not found."
        exit 1
    fi
    
    if ! command -v pip &> /dev/null && ! command -v pip3 &> /dev/null; then
        log_error "pip not found."
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        log_error "AWS credentials not configured. Run 'aws configure'"
        exit 1
    fi
    
    log_success "Prerequisites check passed!"
}

echo ""
echo "╔════════════════════════════════════════════════════════╗"
echo "║     RFP LAMBDA FUNCTIONS DEPLOYMENT                   ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""
echo "Environment: $ENVIRONMENT"
echo "Region: $REGION"
echo "Functions: ${#LAMBDA_FUNCTIONS[@]}"
echo ""

check_prerequisites

# Create temp directory for packages
TEMP_DIR="temp_packages"
mkdir -p "$TEMP_DIR"

SUCCESS_COUNT=0
FAIL_COUNT=0
FAILED_FUNCTIONS=()

# Package and deploy each Lambda function
for FUNCTION_NAME in "${LAMBDA_FUNCTIONS[@]}"; do
    log_info "Processing: $FUNCTION_NAME"
    
    SOURCE_DIR="lambdas/$FUNCTION_NAME"
    PACKAGE_DIR="$TEMP_DIR/$FUNCTION_NAME"
    ZIP_FILE="$TEMP_DIR/${FUNCTION_NAME}.zip"
    
    # Check if source directory exists
    if [ ! -d "$SOURCE_DIR" ]; then
        log_error "Source directory not found: $SOURCE_DIR"
        ((FAIL_COUNT++))
        FAILED_FUNCTIONS+=("$FUNCTION_NAME")
        continue
    fi
    
    # Clean previous package
    rm -rf "$PACKAGE_DIR"
    rm -f "$ZIP_FILE"
    mkdir -p "$PACKAGE_DIR"
    
    echo "  [1/5] Copying function code..."
    cp -r "$SOURCE_DIR"/* "$PACKAGE_DIR/"
    
    echo "  [2/5] Copying shared libraries..."
    cp -r shared/ "$PACKAGE_DIR/"
    
    echo "  [3/5] Installing dependencies..."
    if [ -f "$SOURCE_DIR/requirements.txt" ]; then
        pip3 install -r "$SOURCE_DIR/requirements.txt" -t "$PACKAGE_DIR/" --quiet
    else
        log_warning "No requirements.txt found for $FUNCTION_NAME"
    fi
    
    # Install base requirements
    if [ -f "requirements.txt" ]; then
        pip3 install -r requirements.txt -t "$PACKAGE_DIR/" --quiet
    fi
    
    echo "  [4/5] Creating deployment package..."
    cd "$PACKAGE_DIR"
    zip -r "../${FUNCTION_NAME}.zip" . -q -x "*.pyc" "*__pycache__*" "*.git*" "*.DS_Store"
    cd - > /dev/null
    
    echo "  [5/5] Deploying to AWS Lambda..."
    
    # Try to update function code
    if aws lambda update-function-code \
        --function-name "$FUNCTION_NAME" \
        --zip-file "fileb://$ZIP_FILE" \
        --region "$REGION" \
        --publish \
        > /dev/null 2>&1; then
        log_success "✅ Deployed: $FUNCTION_NAME"
        ((SUCCESS_COUNT++))
    else
        log_error "❌ Failed to deploy: $FUNCTION_NAME (function may not exist)"
        log_warning "   Run 'aws lambda create-function' first or use infrastructure deployment"
        ((FAIL_COUNT++))
        FAILED_FUNCTIONS+=("$FUNCTION_NAME")
    fi
    
    echo ""
done

# Cleanup
log_info "Cleaning up temporary files..."
rm -rf "$TEMP_DIR"

# Summary
echo ""
echo "╔════════════════════════════════════════════════════════╗"
echo "║              DEPLOYMENT SUMMARY                       ║"
echo "╚════════════════════════════════════════════════════════╝"
echo ""
echo "✅ Successful: $SUCCESS_COUNT"
echo "❌ Failed: $FAIL_COUNT"

if [ $FAIL_COUNT -gt 0 ]; then
    echo ""
    echo "Failed functions:"
    for func in "${FAILED_FUNCTIONS[@]}"; do
        echo "  - $func"
    done
    echo ""
    log_warning "Some functions failed to deploy. Check that they exist in AWS Lambda."
    exit 1
fi

echo ""
log_success "🎉 All Lambda functions deployed successfully!"
echo ""

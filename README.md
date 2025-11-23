[![CI/CD](https://github.com/billqhan/rfp-lambdas/actions/workflows/ci-cd.yml/badge.svg)](https://github.com/billqhan/rfp-lambdas/actions)
# RFP Response Platform - Lambda Functions

Python Lambda functions for the RFP Response Platform backend processing.

## Architecture

This repository contains all AWS Lambda functions for:
- SAM.gov data ingestion and processing
- Opportunity matching and scoring
- Report generation
- Workflow orchestration
- Event-driven processing

## Project Structure

```
rfp-lambdas/
├── lambdas/                  # Individual Lambda function handlers
│   ├── sam-gov-daily-download/
│   ├── sam-json-processor/
│   ├── sam-batch-matching/
│   ├── sam-generate-match-reports/
│   ├── sam-web-reports/
│   ├── sam-daily-email-notification/
│   └── ...
├── shared/                   # Shared libraries and utilities
│   ├── aws_helpers/          # AWS service wrappers
│   ├── bedrock_helpers/      # Bedrock AI utilities
│   ├── data_models/          # Data classes and schemas
│   ├── sam_gov/              # SAM.gov API client
│   └── utils/                # Common utilities
├── tests/                    # Unit and integration tests
├── scripts/                  # Deployment and utility scripts
├── requirements.txt          # Python dependencies
└── README.md                 # This file
```

## Lambda Functions

### Data Ingestion
- **sam-gov-daily-download** - Downloads daily opportunity data from SAM.gov
- **sam-json-processor** - Processes downloaded JSON files and stores in DynamoDB

### Matching & Scoring
- **sam-batch-matching** - Batch processes opportunities for matching
- **sam-generate-match-reports** - Generates detailed match reports

### Reporting
- **sam-web-reports** - Generates web-accessible reports
- **sam-daily-email-notification** - Sends daily notification emails

### Workflow
- **sam-merge-and-archive-result-logs** - Consolidates and archives logs
- **sam-produce-website** - Generates static website content

## Development

### Prerequisites

- Python 3.11+
- AWS CLI configured
- Docker (for local testing with SAM)

### Setup

```bash
# Create virtual environment
python3 -m venv .venv
source .venv/bin/activate  # On Windows: .venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Install development dependencies
pip install -e .
```

### Running Tests

```bash
# Run all tests
pytest

# Run with coverage
pytest --cov=lambdas --cov=shared --cov-report=html

# Run specific test file
pytest tests/test_sam_processor.py

# Run with verbose output
pytest -v
```

### Code Quality

```bash
# Format code
black lambdas/ shared/

# Lint code
flake8 lambdas/ shared/

# Type checking
mypy lambdas/ shared/
```

## Deployment

### Automated Deployment (Recommended)

The CI/CD pipeline automatically deploys Lambda functions:
- **Dev**: Push to `develop` branch → deploys to development environment
- **Prod**: Push to `main` branch → deploys to production environment

See [.github/workflows/ci-cd.yml](.github/workflows/ci-cd.yml) for pipeline configuration.

### Manual Deployment Script

Use the deployment script for local/manual deployments or hotfixes:

```bash
# Deploy all Lambda functions to dev
./deploy-lambdas.sh dev

# Deploy all functions to production
./deploy-lambdas.sh prod

# Deploy a single function
./deploy-lambdas.sh dev sam-json-processor

# Set custom AWS region
export AWS_REGION=us-west-2
./deploy-lambdas.sh dev
```

The script will:
1. ✅ Validate prerequisites (AWS CLI, Python, pip)
2. 📦 Package each function with dependencies
3. 📚 Include shared libraries automatically
4. 🚀 Deploy to AWS Lambda (updates existing functions)
5. ✨ Clean up temporary files
6. 📊 Display deployment summary

**Prerequisites:**
- AWS CLI configured with valid credentials
- Lambda functions must exist in AWS (create via infrastructure deployment first)
- IAM permissions to update Lambda functions

### First-Time Setup

If Lambda functions don't exist yet, deploy infrastructure first:

```bash
cd ../rfp-infrastructure
./scripts/deploy-infra.sh dev
```

This creates all Lambda functions, IAM roles, event triggers, and dependencies.

## Environment Variables

Each Lambda function requires specific environment variables set in CloudFormation:

Common variables:
- `ENVIRONMENT` - Environment name (dev, staging, prod)
- `BUCKET_PREFIX` - S3 bucket prefix
- `SAM_API_KEY` - SAM.gov API key (from Secrets Manager)
- `KNOWLEDGE_BASE_ID` - Bedrock Knowledge Base ID

Function-specific variables are documented in each function's directory.

## Shared Libraries

### aws_helpers
AWS service wrappers for S3, DynamoDB, SQS, Secrets Manager, etc.

```python
from shared.aws_helpers import S3Helper, DynamoDBHelper

s3 = S3Helper()
data = s3.read_json('bucket-name', 'key.json')

dynamo = DynamoDBHelper('table-name')
item = dynamo.get_item({'id': '123'})
```

### bedrock_helpers
Bedrock AI integration for matching and content generation.

```python
from shared.bedrock_helpers import BedrockClient

bedrock = BedrockClient()
response = bedrock.invoke_model(prompt, model_id='anthropic.claude-3-sonnet')
```

### sam_gov
SAM.gov API client for opportunity data.

```python
from shared.sam_gov import SAMGovClient

client = SAMGovClient(api_key=api_key)
opportunities = client.get_opportunities(posted_from='2024-01-01')
```

## Testing

### Unit Tests

```python
# tests/lambdas/test_sam_processor.py
def test_process_opportunity():
    event = {'Records': [...]}
    result = lambda_handler(event, {})
    assert result['statusCode'] == 200
```

### Integration Tests

```python
# tests/integration/test_workflow.py
@mock_aws
def test_full_workflow():
    # Test complete workflow with mocked AWS services
    pass
```

### Local Testing with SAM

```bash
# Test Lambda function locally
sam local invoke SamJsonProcessor -e events/s3-event.json

# Start API Gateway locally
sam local start-api
```

## CI/CD

GitHub Actions workflow automatically:
1. Runs tests and linting
2. Validates contract compliance
3. Packages Lambda functions
4. Deploys to AWS (on main branch)

See `.github/workflows/deploy.yml` for details.

## Contract Validation

Lambda functions validate against event schemas from `rfp-infrastructure/rfp-contracts/events/`:
- `workflow-event.schema.json` - Workflow event structure
- Request/response schemas from OpenAPI specs

## Monitoring

All Lambda functions are monitored via:
- CloudWatch Logs - Function execution logs
- CloudWatch Metrics - Invocations, errors, duration
- CloudWatch Alarms - Error rate, throttling
- X-Ray tracing - Distributed tracing

Access dashboards from CloudFormation outputs.

## Troubleshooting

### Function Timeout

Increase timeout in CloudFormation template or add pagination for large datasets.

### Memory Issues

Increase memory allocation in CloudFormation template (also increases CPU).

### Permission Errors

Verify IAM role has required permissions in `rfp-infrastructure/cloudformation/core/iam-security-policies.yaml`.

### Cold Starts

- Use provisioned concurrency for critical functions
- Minimize dependencies in deployment package
- Use layers for common dependencies

## Resources

- [AWS Lambda Documentation](https://docs.aws.amazon.com/lambda/)
- [Boto3 Documentation](https://boto3.amazonaws.com/v1/documentation/api/latest/index.html)
- [rfp-infrastructure Repository](https://github.com/billqhan/rfp-infrastructure)

## License

Internal use only - RFP Response Platform

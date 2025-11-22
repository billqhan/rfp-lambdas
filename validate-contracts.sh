#!/bin/bash
set -e

echo "🔍 Validating API contracts for rfp-lambdas..."

# Check if contracts submodule is initialized
if [ ! -d "contracts/rfp-contracts" ]; then
    echo "❌ Contracts not found. Run: git submodule update --init --recursive"
    exit 1
fi

echo "✅ Contracts submodule present"

# Check OpenAPI spec exists
if [ -f "contracts/rfp-contracts/openapi/api-gateway.yaml" ]; then
    echo "✅ OpenAPI spec found"
else
    echo "❌ OpenAPI spec not found"
    exit 1
fi

# Check event schemas exist
if [ -f "contracts/rfp-contracts/events/workflow-event.schema.json" ]; then
    echo "✅ Event schemas found"
else
    echo "⚠️  Event schemas not found"
fi

# Validate JSON schemas if Python jsonschema is available
if command -v python3 &> /dev/null; then
    echo "📋 Checking JSON schema validation..."
    python3 << 'PYTHON'
import json
import os
import sys

schema_dir = "contracts/rfp-contracts/events"
if os.path.exists(schema_dir):
    for filename in os.listdir(schema_dir):
        if filename.endswith(".schema.json"):
            filepath = os.path.join(schema_dir, filename)
            try:
                with open(filepath) as f:
                    schema = json.load(f)
                print(f"  ✅ {filename} is valid JSON")
            except json.JSONDecodeError as e:
                print(f"  ❌ {filename} has invalid JSON: {e}")
                sys.exit(1)
else:
    print("  ⚠️  No event schemas directory found")
PYTHON
fi

echo ""
echo "✅ Contract validation complete!"

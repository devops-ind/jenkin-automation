#!/bin/bash
# deploy automation script

set -e

ENVIRONMENT=${1:-production}
INVENTORY="ansible/inventories/$ENVIRONMENT/hosts.yml"

echo "Running deploy for $ENVIRONMENT environment"

# Add your script logic here
case "$ENVIRONMENT" in
    production)
        echo "Executing deploy for production"
        ;;
    staging)
        echo "Executing deploy for staging"
        ;;
    *)
        echo "Unknown environment: $ENVIRONMENT"
        exit 1
        ;;
esac

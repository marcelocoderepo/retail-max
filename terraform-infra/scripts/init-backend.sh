#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# init-backend.sh - Create Azure Storage Account for Terraform state
#
# Run this ONCE before any terraform init.
# Requires: Azure CLI authenticated (az login)
# ==============================================================================

RESOURCE_GROUP="rg-retailmax-tfstate"
STORAGE_ACCOUNT="stretailmaxtfstate"
CONTAINER="tfstate"
LOCATION="eastus2"

echo "==> Creating Resource Group: $RESOURCE_GROUP"
az group create --name "$RESOURCE_GROUP" --location "$LOCATION"

echo "==> Creating Storage Account: $STORAGE_ACCOUNT"
az storage account create \
  --name "$STORAGE_ACCOUNT" \
  --resource-group "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --sku Standard_GRS \
  --kind StorageV2 \
  --allow-blob-public-access false \
  --require-infrastructure-encryption true \
  --min-tls-version TLS1_2

echo "==> Enabling versioning and soft-delete (90 days)"
az storage account blob-service-properties update \
  --account-name "$STORAGE_ACCOUNT" \
  --resource-group "$RESOURCE_GROUP" \
  --enable-versioning true \
  --enable-delete-retention true \
  --delete-retention-days 90 \
  --enable-container-delete-retention true \
  --container-delete-retention-days 90

echo "==> Creating container: $CONTAINER"
az storage container create \
  --name "$CONTAINER" \
  --account-name "$STORAGE_ACCOUNT"

echo "==> Creating delete lock to protect state"
az lock create \
  --name "tfstate-lock" \
  --resource-group "$RESOURCE_GROUP" \
  --resource-type Microsoft.Storage/storageAccounts \
  --resource "$STORAGE_ACCOUNT" \
  --lock-type CanNotDelete \
  --notes "Protege Terraform state - NAO remover"

echo ""
echo "==> Done! Storage Account for Terraform state created."
echo ""
echo "Next steps:"
echo "  1. Get the access key:"
echo "     az storage account keys list --account-name $STORAGE_ACCOUNT --resource-group $RESOURCE_GROUP --query '[0].value' -o tsv"
echo "  2. Save it in .secrets/terraform-backend.env as TF_BACKEND_ACCESS_KEY"
echo "  3. Run: source .secrets/terraform-backend.env"
echo "  4. Run: cd environments/dev && terraform init"

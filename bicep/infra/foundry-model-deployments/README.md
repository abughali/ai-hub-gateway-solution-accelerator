# Microsoft Foundry Model Deployments

## Overview

Standalone module to manage model deployments on existing Microsoft Foundry instances — without redeploying the full AI Hub Gateway infrastructure.

Use this to independently:
- **Add** new model deployments to Foundry instances
- **Update** capacity or SKU of existing deployments
- **Remove** models (by excluding them from config, then deleting via portal/CLI)

## What Gets Created

| Resource | Description |
|----------|-------------|
| **Model Deployments** | `Microsoft.CognitiveServices/accounts/deployments` resources on each target Foundry account |

## Prerequisites

- Existing Microsoft Foundry account(s) in the target resource group
- Deploying identity has **Contributor** role on the resource group
- Azure CLI with Bicep support

## Quick Start

### 1. Configure Your Deployments

Edit `main.bicepparam`:

- `aiFoundryInstances` — array of Foundry account names (referenced by index)
- `aiFoundryModelsConfig` — flat array of models; use `aiserviceIndex` to target a specific instance, or omit to deploy to all

```bicep
param aiFoundryInstances = [
  'aif-myproject-prod-swc-01'   // Instance 0 - Sweden Central
  'aif-myproject-prod-eus-01'   // Instance 1 - East US
]

param aiFoundryModelsConfig = [
  // --- Deploy to Instance 0 only ---
  {
    name:            'gpt-5.1'
    publisher:       'OpenAI'
    version:         '2025-11-13'
    sku:             'GlobalStandard'
    capacity:        100
    aiserviceIndex:  0
  }
  // --- Deploy to Instance 1 only ---
  {
    name:            'gpt-5'
    publisher:       'OpenAI'
    version:         '2025-08-07'
    sku:             'GlobalStandard'
    capacity:        100
    aiserviceIndex:  1
  }
  // --- Deploy to ALL instances (no aiserviceIndex) ---
  {
    name:            'DeepSeek-R1'
    publisher:       'DeepSeek'
    version:         '1'
    sku:             'GlobalStandard'
    capacity:        50
  }
  {
    name:            'text-embedding-3-large'
    publisher:       'OpenAI'
    version:         '1'
    sku:             'GlobalStandard'
    capacity:        100
  }
]
```

### 2. Deploy

```bash
az deployment group create \
  --resource-group <foundry-resource-group> \
  --template-file main.bicep \
  --parameters main.bicepparam
```

## Model Configuration Properties

| Property | Type | Required | Description |
|----------|------|----------|-------------|
| `name` | string | Yes | Model name (e.g., `gpt-5`, `DeepSeek-R1`) |
| `publisher` | string | Yes | Publisher/format (`OpenAI`, `DeepSeek`, `Microsoft`) |
| `version` | string | Yes | Model version (e.g., `2025-08-07`) |
| `sku` | string | Yes | SKU name (`GlobalStandard`, `Standard`, etc.) |
| `capacity` | int | Yes | TPM quota capacity |
| `aiserviceIndex` | int | No | Index into `aiFoundryInstances` to target a specific instance. Omit to deploy to all instances. |

## Common Operations

### Add a model to a specific instance

Add a new entry to `aiFoundryModelsConfig` with the corresponding `aiserviceIndex` and redeploy.

### Deploy a model to all instances

Add a new entry to `aiFoundryModelsConfig` without `aiserviceIndex` and redeploy.

### Update model capacity

Change the `capacity` value and redeploy — Bicep updates the existing deployment in-place.

### Remove a model

Remove the entry from `aiFoundryModelsConfig`. Note: Bicep incremental mode does **not** delete resources omitted from the template. After redeploying, delete the deployment via:

```bash
az cognitiveservices account deployment delete \
  --name <foundry-account-name> \
  --resource-group <resource-group> \
  --deployment-name <model-name>
```

### Add a new Foundry instance

Add the account name to `aiFoundryInstances` and reference its index in any instance-specific models.

## Pipeline

An Azure DevOps pipeline is provided at `.azdo/pipelines/foundry-model-deployments.yml`. This uses Microsoft-hosted agents (ARM control plane only — no private endpoint access needed).

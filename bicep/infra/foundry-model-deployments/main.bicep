/**
 * @module foundry-model-deployments
 * @description Manages model deployments on existing Microsoft Foundry instances
 *              without re-provisioning the full AI Hub Gateway infrastructure.
 *
 * Scope: Resource Group (the RG that contains the Microsoft Foundry accounts)
 *
 * This standalone module allows you to:
 *   - Add new model deployments to existing Microsoft Foundry instances
 *   - Update capacity/SKU of existing deployments
 *   - Remove models by excluding them from the configuration array
 *
 * Prerequisites:
 *   - Microsoft Foundry account(s) already exist in the target resource group
 *   - The deploying identity has Contributor role on the resource group
 *
 * Usage:
 *   az deployment group create \
 *     --resource-group <foundry-resource-group> \
 *     --template-file main.bicep \
 *     --parameters main.bicepparam
 *
 * IMPORTANT: Bicep uses incremental mode — any model NOT listed in the configuration will
 *            remain unless you explicitly remove it via the portal/CLI.
 */

targetScope = 'resourceGroup'

// ============================================================================
// PARAMETERS
// ============================================================================

@description('Array of Microsoft Foundry account names to deploy models to.')
@metadata({
  example: [
    'aif-myproject-prod-swc-01'
    'aif-myproject-prod-eus-01'
  ]
})
param aiFoundryInstances array

@description('Flat array of model deployment configurations. Use "aiserviceIndex" to target a specific instance by index, or omit to deploy to all instances.')
@metadata({
  example: [
    { name: 'gpt-5', publisher: 'OpenAI', version: '2025-08-07', sku: 'GlobalStandard', capacity: 100, aiserviceIndex: 0 }
    { name: 'DeepSeek-R1', publisher: 'DeepSeek', version: '1', sku: 'GlobalStandard', capacity: 50 }
  ]
})
param aiFoundryModelsConfig array

// ============================================================================
// MODULES
// ============================================================================

module modelDeployments '../modules/foundry/deployments.bicep' = [for (instance, i) in aiFoundryInstances: {
  name: take('models-${instance}', 64)
  params: {
    cognitiveServiceName: instance
    modelsConfig: filter(aiFoundryModelsConfig, model => !contains(model, 'aiserviceIndex') || aiFoundryInstances[model.aiserviceIndex] == instance)
  }
}]

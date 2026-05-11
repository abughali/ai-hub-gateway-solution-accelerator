using './main.bicep'

// ============================================================================
// FOUNDRY MODEL DEPLOYMENTS CONFIGURATION
// ============================================================================
// Use 'aiserviceIndex' to target a specific Foundry instance by index.
// Omit 'aiserviceIndex' to deploy the model to ALL instances.
// To add a model: add an entry to aiFoundryModelsConfig.
// To remove a model: remove the entry (then delete via portal/CLI if needed).
// To update capacity: change the capacity value and redeploy.
// ============================================================================

param aiFoundryInstances = [
  '<your-foundry-account-name-0>'   // Instance 0 - e.g., aif-myproject-prod-swc-01
  '<your-foundry-account-name-1>'   // Instance 1 - e.g., aif-myproject-prod-eus-01
]

param aiFoundryModelsConfig = [
  // --- Instance 0 only ---
  {
    name: 'gpt-5.1'
    publisher: 'OpenAI'
    version: '2025-11-13'
    sku: 'GlobalStandard'
    capacity: 100
    aiserviceIndex: 0
  }
  {
    name: 'Phi-4'
    publisher: 'Microsoft'
    version: '3'
    sku: 'GlobalStandard'
    capacity: 50
    aiserviceIndex: 0
  }
  // --- Instance 1 only ---
  {
    name: 'gpt-5'
    publisher: 'OpenAI'
    version: '2025-08-07'
    sku: 'GlobalStandard'
    capacity: 100
    aiserviceIndex: 1
  }
  // --- Both instances (no aiserviceIndex = deploy to all) ---
  {
    name: 'DeepSeek-R1'
    publisher: 'DeepSeek'
    version: '1'
    sku: 'GlobalStandard'
    capacity: 50
  }
  {
    name: 'text-embedding-3-large'
    publisher: 'OpenAI'
    version: '1'
    sku: 'GlobalStandard'
    capacity: 100
  }
]

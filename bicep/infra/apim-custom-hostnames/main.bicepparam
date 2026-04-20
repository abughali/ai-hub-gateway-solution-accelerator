using './main.bicep'

// =====================================================================
//    CORE — Identify existing resources
// =====================================================================
param apimServiceName = '<your-apim-service-name>'
param managedIdentityName = '<your-managed-identity-name>'
param keyVaultName = '<your-key-vault-name>'
// =====================================================================
//    FEATURE FLAGS — Toggle which certificates to deploy
// =====================================================================
param deployGatewayCert = true
param deployPortalCert = true
param deployManagementCert = true

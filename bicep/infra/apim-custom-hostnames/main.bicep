/**
 * @module apim-custom-hostnames
 * @description Configures custom hostnames on an existing APIM instance provisioned by the main
 *              AI Hub Gateway Solution Accelerator. Deploys PFX certificates as Key Vault secrets
 *              via the ARM control plane (bypassing the Key Vault data-plane firewall), so APIM
 *              can reference them through `keyVaultId` bindings — without re-provisioning the
 *              APIM service or any surrounding infrastructure.
 *
 * Scope: Resource Group (the RG that already contains the APIM instance and Key Vault)
 *
 * Prerequisites:
 *   - APIM service already exists in the target resource group
 *   - Key Vault already exists in the same resource group
 *   - User-assigned managed identity already exists and is attached to APIM
 *   - APIM managed identity has the 'Key Vault Secrets User' role on the Key Vault
 *   - PFX certificates are password-free (APIM cannot decrypt password-protected PFX via keyVaultId)
 *
 * Companion pipeline: .azdo/pipelines/apim-custom-hostnames.yml
 *   - Passes base64-encoded PFX content as @secure() parameters at deployment time
 *   - Runs `az apim update --add hostnameConfigurations` to bind the uploaded secrets
 */

targetScope = 'resourceGroup'

// =====================================================================
//    CORE — Identify existing resources
// =====================================================================
@description('Name of the existing API Management service')
param apimServiceName string

@description('Name of the existing APIM user-assigned managed identity')
param managedIdentityName string

@description('Name of the existing Key Vault')
param keyVaultName string

// =====================================================================
//    FEATURE FLAGS — Toggle which certificates to deploy
// =====================================================================
@description('Deploy gateway certificate')
param deployGatewayCert bool = true

@description('Deploy portal certificate')
param deployPortalCert bool = true

@description('Deploy management certificate')
param deployManagementCert bool = true

// =====================================================================
//    CERTIFICATE PARAMETERS
// =====================================================================
@description('Base64-encoded PFX content for gateway certificate')
@secure()
param gatewayCertBase64 string = ''

@description('Base64-encoded PFX content for portal certificate')
@secure()
param portalCertBase64 string = ''

@description('Base64-encoded PFX content for management certificate')
@secure()
param managementCertBase64 string = ''

// =====================================================================
//    EXISTING RESOURCES
// =====================================================================
resource apimService 'Microsoft.ApiManagement/service@2024-05-01' existing = {
  name: apimServiceName
}

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: managedIdentityName
}

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: keyVaultName
}

// =====================================================================
//    KEY VAULT SECRETS — Deploy PFX certs via ARM (bypasses firewall)
// =====================================================================
resource gatewayCertSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = if (deployGatewayCert && !empty(gatewayCertBase64)) {
  parent: keyVault
  name: 'gateway-cert'
  properties: {
    value: gatewayCertBase64
    contentType: 'application/x-pkcs12'
  }
}

resource portalCertSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = if (deployPortalCert && !empty(portalCertBase64)) {
  parent: keyVault
  name: 'portal-cert'
  properties: {
    value: portalCertBase64
    contentType: 'application/x-pkcs12'
  }
}

resource managementCertSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = if (deployManagementCert && !empty(managementCertBase64)) {
  parent: keyVault
  name: 'mgmt-cert'
  properties: {
    value: managementCertBase64
    contentType: 'application/x-pkcs12'
  }
}

// =====================================================================
//    OUTPUTS
// =====================================================================
output apimName string = apimService.name
output managedIdentityClientId string = managedIdentity.properties.clientId
output keyVaultUri string = keyVault.properties.vaultUri

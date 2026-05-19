# APIM Custom Hostnames

Configure custom hostnames on an existing API Management instance using certificates stored in Azure Key Vault.

This deployment uses the ARM control plane to import PFX certificates into Key Vault as secrets, bypassing Key Vault firewall restrictions. It then configures APIM custom hostname bindings via `az apim update`.

Notes:
- Update the custom hostname configuration of an **existing** API Management instance without re-provisioning the APIM service or surrounding infrastructure.
- This deployment is designed to run **after** the main accelerator (`bicep/infra/main.bicep`) has provisioned the full environment.
- The APIM managed identity must already have the **Key Vault Secrets User** role on the target Key Vault (provisioned by default in the main deployment).

## What this deployment does

| Step | Action |
|---|---|
| **Certificate Import** | Deploys PFX certificates as Key Vault secrets via ARM (bypasses Key Vault firewall) |
| **Hostname Configuration** | Applies all custom hostnames (Gateway / Portal / Management) in a single `az apim update --set hostnameConfigurations=...` call, bound to their Key Vault certificates |

## What this deployment does NOT do

- Provision a new APIM service instance or Key Vault
- Create or modify managed identities or RBAC assignments
- Create DNS records (must be configured separately)
- Modify networking, VNet, or private endpoint settings

## Prerequisites

1. The APIM service referenced by `apimServiceName` must already exist in the target resource group.
2. The user-assigned managed identity referenced by `managedIdentityName` must already exist in the same resource group.
3. The Key Vault referenced by `keyVaultName` must already exist in the same resource group.
4. The APIM managed identity must have the **Key Vault Secrets User** role on the Key Vault.
5. PFX certificate files uploaded to Azure DevOps **Pipelines > Library > Secure Files**.
6. DNS CNAME records pointing custom hostnames to the APIM gateway URL (e.g., `apim-name.azure-api.net`).

## Usage

### 1. Configure Parameters

Edit `main.bicepparam` to match your environment:

```bicep
param apimServiceName = 'my-apim-instance'
param managedIdentityName = 'my-apim-identity'
param keyVaultName = 'my-key-vault'
```

### 2. Toggle Feature Flags

Enable or disable individual certificate deployments:

```bicep
param deployGatewayCert = true
param deployPortalCert = true
param deployManagementCert = true
```

### 3. Upload Certificates

Upload PFX certificate files to Azure DevOps:

1. Navigate to **Pipelines > Library > Secure Files**
2. Upload each PFX file (e.g., `gateway.pfx`, `portal.pfx`, `management.pfx`)
3. Authorize the pipeline to use the secure files

> **If your PFX files are password-protected**, you must strip the password before uploading.
> APIM cannot decrypt password-protected PFX files when reading them from Key Vault via `keyVaultId` references.
>
> **Linux / macOS:**
> ```bash
> openssl pkcs12 -in gateway.pfx -out gateway.pem -nodes -password pass:YOUR_PASSWORD
> openssl pkcs12 -export -in gateway.pem -out gateway-nopass.pfx -passout pass:
> rm gateway.pem
> ```
>
> **Windows (PowerShell):**
> ```powershell
> $pass = ConvertTo-SecureString -String "YOUR_PASSWORD" -AsPlainText -Force
> $cert = Get-PfxCertificate -FilePath .\gateway.pfx -Password $pass
> Export-PfxCertificate -Cert $cert -FilePath .\gateway-nopass.pfx -Password (New-Object SecureString)
> ```
>
> Upload the resulting `*-nopass.pfx` files to Secure Files.

### 4. Run the Pipeline

Run the `apim-custom-hostnames` pipeline with the following parameters:

| Parameter | Example Value |
|---|---|
| `gatewayHostname` | `api.yourdomain.com` |
| `portalHostname` | `portal.yourdomain.com` |
| `managementHostname` | `management.yourdomain.com` |
| `gatewayCertSecureFile` | `gateway.pfx` |
| `portalCertSecureFile` | `portal.pfx` |
| `managementCertSecureFile` | `management.pfx` |

### Manual Deployment (without pipeline)

```bash
# Base64-encode the PFX files
GATEWAY_B64=$(base64 -w 0 gateway.pfx)
PORTAL_B64=$(base64 -w 0 portal.pfx)
MGMT_B64=$(base64 -w 0 management.pfx)

# Deploy certificates to Key Vault via ARM
az deployment group create \
  --name apim-custom-hostnames-$(date +%Y%m%d%H%M%S) \
  --resource-group <your-resource-group> \
  --template-file main.bicep \
  --parameters main.bicepparam \
  --parameters \
    gatewayCertBase64="$GATEWAY_B64" \
    portalCertBase64="$PORTAL_B64" \
    managementCertBase64="$MGMT_B64"

# Update APIM hostnames
CLIENT_ID=$(az identity show --name <identity-name> --resource-group <rg> --query clientId -o tsv)
KV_BASE="https://<kv-name>.vault.azure.net/secrets"

# Build the full hostnameConfigurations array and apply it in a single PATCH.
# Entries with empty hostnames are dropped so you can omit any of the three.
HOSTNAME_CONFIGS=$(jq -nc \
  --arg gw     "api.yourdomain.com" \
  --arg portal "portal.yourdomain.com" \
  --arg mgmt   "management.yourdomain.com" \
  --arg cid    "$CLIENT_ID" \
  --arg kvbase "$KV_BASE" '
  [
    {type:"Proxy",           hostName:$gw,     keyVaultId:($kvbase+"/gateway-cert"), identityClientId:$cid, defaultSslBinding:true},
    {type:"DeveloperPortal", hostName:$portal, keyVaultId:($kvbase+"/portal-cert"),  identityClientId:$cid},
    {type:"Management",      hostName:$mgmt,   keyVaultId:($kvbase+"/mgmt-cert"),    identityClientId:$cid}
  ] | map(select(.hostName != ""))')

az apim update --name <apim-name> --resource-group <rg> \
  --set hostnameConfigurations="$HOSTNAME_CONFIGS"
```

## How it works

### Key Vault Firewall Bypass

The Key Vault in this solution has public network access **disabled**. The Bicep deployment creates Key Vault secrets via the ARM control plane (`management.azure.com`), which bypasses the Key Vault data plane firewall. This means:

- No need to temporarily open the Key Vault firewall
- No need for a self-hosted agent in the VNet
- No additional RBAC beyond **Contributor** on the resource group

### APIM Certificate Binding

APIM reads certificates from Key Vault at runtime using the **secrets** endpoint (not the certificates endpoint). The APIM user-assigned managed identity authenticates to Key Vault using the **Key Vault Secrets User** role, which is already assigned in the main deployment.

## Verification

1. Verify certificates exist in Key Vault:
   ```bash
   az keyvault secret list --vault-name <kv-name> --query "[].name"
   ```

2. Verify APIM hostname configuration:
   ```bash
   az apim show -n <apim-name> -g <rg> --query hostnameConfigurations
   ```

3. Test custom hostname (after DNS configuration):
   ```bash
   curl -I https://api.yourdomain.com
   ```

## Certificate Renewal

To renew certificates, re-run the pipeline with updated PFX files. Both `az deployment group create` (for KV secrets) and `az apim update` (for hostnames) are idempotent.

## Parameter Reference

### Core Parameters

| Parameter | Required | Description |
|---|---|---|
| `apimServiceName` | Yes | Name of the existing APIM instance |
| `managedIdentityName` | Yes | Name of the existing user-assigned managed identity |
| `keyVaultName` | Yes | Name of the existing Key Vault |

### Feature Flags

| Parameter | Default | Description |
|---|---|---|
| `deployGatewayCert` | `true` | Deploy gateway certificate to Key Vault |
| `deployPortalCert` | `true` | Deploy portal certificate to Key Vault |
| `deployManagementCert` | `true` | Deploy management certificate to Key Vault |

### Pipeline Variables

| Variable | Description |
|---|---|
| `resourceGroupName` | Target resource group |
| `azureSubscription` | ADO service connection name |
| `templateFile` | Path to the Bicep template |
| `paramsFile` | Path to the Bicep parameter file |
| `gatewayHostname` | Custom gateway hostname (e.g., `api.yourdomain.com`) |
| `portalHostname` | Custom developer portal hostname (e.g., `portal.yourdomain.com`) |
| `managementHostname` | Custom management hostname (e.g., `management.yourdomain.com`) |
| `gatewayCertSecureFile` | ADO Secure File name for gateway PFX |
| `portalCertSecureFile` | ADO Secure File name for portal PFX |
| `managementCertSecureFile` | ADO Secure File name for management PFX |

### Certificate Parameters (deployment-time only)

| Parameter | Description |
|---|---|
| `gatewayCertBase64` | Base64-encoded PFX for gateway — pass via CLI |
| `portalCertBase64` | Base64-encoded PFX for portal — pass via CLI |
| `managementCertBase64` | Base64-encoded PFX for management — pass via CLI |

## File structure

```
apim-custom-hostnames/
├── main.bicep          # Deployment template (resource group scope)
├── main.bicepparam     # Parameter file — configure before deploying
└── README.md           # This guide
```

Pipeline definition: `.azdo/pipelines/apim-custom-hostnames.yml`
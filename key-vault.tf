# One vault per app and environment, RBAC only (no access policies). The vault
# is the boundary: the API reads every secret in it and nothing else does, so
# the role is granted on the vault, and adding a secret needs no new grant.
#
# Network: with app_subnet_id the firewall denies by default and lets in the
# app subnet and key_vault_allowed_ip_ranges. Without a VNet, App Service
# reaches Key Vault over its public endpoint, so the vault accepts public
# traffic and relies on Entra ID and RBAC alone.
resource "azurerm_key_vault" "this" {
  name                          = local.names.key_vault
  location                      = var.location
  resource_group_name           = var.resource_group_name
  tenant_id                     = data.azurerm_client_config.current.tenant_id
  sku_name                      = "standard"
  rbac_authorization_enabled    = true
  purge_protection_enabled      = var.key_vault_purge_protection_enabled
  soft_delete_retention_days    = 7
  public_network_access_enabled = true
  tags                          = var.tags

  network_acls {
    bypass                     = "AzureServices"
    default_action             = var.app_subnet_id == null ? "Allow" : "Deny"
    virtual_network_subnet_ids = var.app_subnet_id == null ? [] : [var.app_subnet_id]
    ip_rules                   = var.app_subnet_id == null ? [] : var.key_vault_allowed_ip_ranges
  }

  lifecycle {
    precondition {
      condition     = length(local.names.key_vault) <= 24
      error_message = "The vault name ${local.names.key_vault} is longer than 24 characters. Shorten workload, environment or unique_suffix."
    }
  }
}

resource "azurerm_role_assignment" "api_secrets_user" {
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_web_app.api.identity[0].principal_id
  principal_type       = "ServicePrincipal"
}

# People who set the secret values. Terraform never does.
resource "azurerm_role_assignment" "secrets_officer" {
  for_each = toset(var.key_vault_secrets_officer_principal_ids)

  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = each.value
}

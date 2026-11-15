# Azure: HCP Terraform dynamic credentials (OIDC) or `az login` locally.
# ARM_SUBSCRIPTION_ID selects the subscription.
provider "azurerm" {
  storage_use_azuread = true

  # azurerm 5.x registers nothing by default; register only what this needs.
  resource_providers_to_register = [
    "Microsoft.Insights",
    "Microsoft.KeyVault",
    "Microsoft.ManagedIdentity",
    "Microsoft.OperationalInsights",
    "Microsoft.Sql",
    "Microsoft.Web",
  ]

  features {
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }

    resource_group {
      prevent_deletion_if_contains_resources = true
    }
  }
}

# GitHub: a GitHub App installation, from GITHUB_APP_ID,
# GITHUB_APP_INSTALLATION_ID and GITHUB_APP_PEM_FILE (or GITHUB_TOKEN locally).
# It needs Administration (environments) and Variables: read and write on the
# app repository only.
provider "github" {
  owner = var.github_owner
}

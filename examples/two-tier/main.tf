# A two-tier app: a front end and an API on one Linux plan, a vault for the
# API's secrets, Application Insights, an identity that only the app
# repository's main branch can deploy as, and that repository's GitHub
# Environment.
locals {
  region = lookup({
    southafricanorth = "zan"
    southafricawest  = "zaw"
    westeurope       = "weu"
    northeurope      = "neu"
    swedencentral    = "sdc"
    uksouth          = "uks"
  }, var.location, var.location)

  suffix = "${var.workload}-${var.environment}-${local.region}${var.unique_suffix}"

  tags = merge({
    workload    = var.workload
    environment = var.environment
    managed_by  = "terraform"
    repo        = "terraform-azurerm-web-app"
  }, var.tags)
}

resource "azurerm_resource_group" "this" {
  name     = "rg-${local.suffix}"
  location = var.location
  tags     = local.tags
}

resource "azurerm_log_analytics_workspace" "this" {
  name                         = "log-${local.suffix}"
  location                     = var.location
  resource_group_name          = azurerm_resource_group.this.name
  sku                          = "PerGB2018"
  retention_in_days            = 30
  daily_quota_gb               = 1
  local_authentication_enabled = false
  tags                         = local.tags
}

module "web_app" {
  source = "../.."

  workload                   = var.workload
  environment                = var.environment
  location                   = var.location
  unique_suffix              = var.unique_suffix
  resource_group_name        = azurerm_resource_group.this.name
  log_analytics_workspace_id = azurerm_log_analytics_workspace.this.id
  tags                       = local.tags

  api_app_settings      = var.api_app_settings
  api_key_vault_secrets = var.api_key_vault_secrets
  sql                   = var.sql

  key_vault_secrets_officer_principal_ids = var.secrets_officer_group_object_id == null ? [] : [var.secrets_officer_group_object_id]

  deploy = {
    github_repository = "${var.github_owner}/${var.app_repository}"
  }
}

module "github_environment" {
  source = "../../modules/github-deploy-environment"

  repository            = var.app_repository
  environment           = module.web_app.deploy_environment
  deployment_branches   = ["main"]
  environment_variables = module.web_app.deployment_variables
}

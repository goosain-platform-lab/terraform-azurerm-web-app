data "azurerm_client_config" "current" {}

locals {
  region_codes = {
    southafricanorth   = "zan"
    southafricawest    = "zaw"
    westeurope         = "weu"
    northeurope        = "neu"
    swedencentral      = "sdc"
    uksouth            = "uks"
    francecentral      = "frc"
    germanywestcentral = "gwc"
    switzerlandnorth   = "szn"
    eastus             = "eus"
    eastus2            = "eus2"
  }

  region = lookup(local.region_codes, var.location, var.location)

  # <type>-<workload>-<environment>-<region>[suffix], with a role token for
  # resources there is more than one of: app-notes-web-lab-zan, app-notes-api-lab-zan.
  base = "${var.workload}-${var.environment}-${local.region}${var.unique_suffix}"
  tail = "${var.environment}-${local.region}${var.unique_suffix}"

  names = {
    plan            = "asp-${local.base}"
    web             = "app-${var.workload}-web-${local.tail}"
    api             = "app-${var.workload}-api-${local.tail}"
    app_insights    = "appi-${local.base}"
    key_vault       = "kv-${local.base}"
    deploy_identity = "id-${var.workload}-deploy-${local.tail}"
    sql_server      = "sql-${local.base}"
    sql_database    = "sqldb-${local.base}"
  }

  # Free and Shared plans can't keep an app loaded.
  always_on = !contains(["F1", "D1"], var.app_service_plan_sku)

  # The GitHub Environment the deploy identity trusts, in GitHub's default
  # subject format. An org that customised its OIDC subject template passes
  # its own subject instead.
  deploy_environment = coalesce(var.deploy.environment, var.environment)
  deploy_oidc_subject = coalesce(
    var.deploy.oidc_subject,
    "repo:${var.deploy.github_repository}:environment:${local.deploy_environment}",
  )
}

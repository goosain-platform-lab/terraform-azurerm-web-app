# Application Insights for the API, workspace-based, with key-based ingestion
# switched off: the API's identity is the only thing that can send telemetry.
resource "azurerm_application_insights" "this" {
  name                         = local.names.app_insights
  location                     = var.location
  resource_group_name          = var.resource_group_name
  application_type             = "web"
  workspace_id                 = var.log_analytics_workspace_id
  local_authentication_enabled = false
  tags                         = var.tags
}

resource "azurerm_role_assignment" "api_telemetry" {
  scope                = azurerm_application_insights.this.id
  role_definition_name = "Monitoring Metrics Publisher"
  principal_id         = azurerm_linux_web_app.api.identity[0].principal_id
  principal_type       = "ServicePrincipal"
}

# Platform logs (HTTP, console, app, audit) for both sites and the vault's
# audit events, all to the same workspace.
resource "azurerm_monitor_diagnostic_setting" "this" {
  for_each = {
    web       = azurerm_linux_web_app.web.id
    api       = azurerm_linux_web_app.api.id
    key_vault = azurerm_key_vault.this.id
  }

  name                       = "diag-to-law"
  target_resource_id         = each.value
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category_group = "allLogs"
  }
}

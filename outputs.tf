output "web_app" {
  description = "The front end: name, ID, hostname and URL."
  value = {
    name             = azurerm_linux_web_app.web.name
    id               = azurerm_linux_web_app.web.id
    default_hostname = azurerm_linux_web_app.web.default_hostname
    url              = "https://${azurerm_linux_web_app.web.default_hostname}"
  }
}

output "api_app" {
  description = "The API: name, ID, hostname, URL and the principal ID of its identity (for data-plane grants such as storage)."
  value = {
    name             = azurerm_linux_web_app.api.name
    id               = azurerm_linux_web_app.api.id
    default_hostname = azurerm_linux_web_app.api.default_hostname
    url              = "https://${azurerm_linux_web_app.api.default_hostname}"
    principal_id     = azurerm_linux_web_app.api.identity[0].principal_id
  }
}

output "key_vault" {
  description = "This app's vault: put the secrets named in api_key_vault_secrets here."
  value = {
    name = azurerm_key_vault.this.name
    id   = azurerm_key_vault.this.id
    uri  = azurerm_key_vault.this.vault_uri
  }
}

output "deploy_identity" {
  description = "The identity GitHub Actions deploys as, and the OIDC subject it trusts."
  value = {
    name         = azurerm_user_assigned_identity.deploy.name
    client_id    = azurerm_user_assigned_identity.deploy.client_id
    principal_id = azurerm_user_assigned_identity.deploy.principal_id
    oidc_subject = local.deploy_oidc_subject
  }
}

output "deployment_variables" {
  description = "Non-secret GitHub Environment variables for the deploy workflow. Pass them to modules/github-deploy-environment."
  value = {
    AZURE_CLIENT_ID       = azurerm_user_assigned_identity.deploy.client_id
    AZURE_TENANT_ID       = data.azurerm_client_config.current.tenant_id
    AZURE_SUBSCRIPTION_ID = data.azurerm_client_config.current.subscription_id
    WEB_APP_NAME          = azurerm_linux_web_app.web.name
    API_APP_NAME          = azurerm_linux_web_app.api.name
  }
}

output "deploy_environment" {
  description = "The GitHub Environment the deploy identity trusts."
  value       = local.deploy_environment
}

output "sql" {
  description = "The SQL server and database, or null when sql is not set."
  value = var.sql == null ? null : {
    server_fqdn   = azurerm_mssql_server.this[0].fully_qualified_domain_name
    database_name = azurerm_mssql_database.this[0].name
  }
}

output "names" {
  description = "Every resource name the module uses."
  value       = local.names
}

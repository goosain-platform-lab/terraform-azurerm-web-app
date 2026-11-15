# One Linux plan, two sites: the front end and the API. Both sites:
#   - HTTPS only, TLS 1.2 or later, FTP off;
#   - FTP and Kudu/Web Deploy basic authentication off, so a deployment needs
#     an Entra ID token (the deploy identity) and never a publish profile;
#   - settings owned by Terraform: plain values here, secrets as Key Vault
#     references, so no secret value is ever stored in state or in GitHub.
resource "azurerm_service_plan" "this" {
  name                = local.names.plan
  location            = var.location
  resource_group_name = var.resource_group_name
  os_type             = "Linux"
  sku_name            = var.app_service_plan_sku
  tags                = var.tags
}

locals {
  # BlobStorage:AccountName, :ContainerName and :PathPrefix to ASP.NET Core.
  api_blob_settings = var.api_blob_storage == null ? {} : {
    for name, value in {
      BlobStorage__AccountName   = var.api_blob_storage.account_name
      BlobStorage__ContainerName = var.api_blob_storage.container_name
      BlobStorage__PathPrefix    = var.api_blob_storage.path_prefix
    } : name => value if value != null
  }

  # App Service resolves these with the API's identity at start-up.
  api_key_vault_references = {
    for setting, secret in var.api_key_vault_secrets :
    setting => "@Microsoft.KeyVault(VaultName=${azurerm_key_vault.this.name};SecretName=${secret})"
  }

  # Telemetry is sent with the API's identity: the component has local
  # (key-based) authentication switched off.
  api_monitoring_settings = {
    APPLICATIONINSIGHTS_CONNECTION_STRING     = azurerm_application_insights.this.connection_string
    APPLICATIONINSIGHTS_AUTHENTICATION_STRING = "Authorization=AAD"
  }

  # No password: the API signs in to SQL with its own identity.
  api_sql_settings = var.sql == null ? {} : {
    ConnectionStrings__DefaultConnection = "Server=tcp:${azurerm_mssql_server.this[0].fully_qualified_domain_name},1433;Database=${azurerm_mssql_database.this[0].name};Authentication=Active Directory Default;Encrypt=True;"
  }
}

#------------------------------------------------------------------------------
# Front end. Static files need no Azure access, so it has no identity.
#------------------------------------------------------------------------------
resource "azurerm_linux_web_app" "web" {
  name                                           = local.names.web
  location                                       = var.location
  resource_group_name                            = var.resource_group_name
  service_plan_id                                = azurerm_service_plan.this.id
  https_only                                     = true
  client_affinity_enabled                        = false
  virtual_network_subnet_id                      = var.app_subnet_id
  ftp_publish_basic_authentication_enabled       = false
  webdeploy_publish_basic_authentication_enabled = false
  app_settings                                   = var.web_app_settings
  tags                                           = var.tags

  site_config {
    always_on               = local.always_on
    http2_enabled           = true
    minimum_tls_version     = "1.2"
    scm_minimum_tls_version = "1.2"
    ftps_state              = "Disabled"
    vnet_route_all_enabled  = var.app_subnet_id != null
    app_command_line        = var.web_stack.startup_command

    application_stack {
      node_version   = var.web_stack.node_version
      dotnet_version = var.web_stack.dotnet_version
    }
  }

  lifecycle {
    precondition {
      condition     = length(local.names.web) <= 60
      error_message = "The site name ${local.names.web} is longer than 60 characters. Shorten workload or unique_suffix."
    }
  }
}

#------------------------------------------------------------------------------
# API. Its system-assigned identity reads this app's secrets and sends
# telemetry; it's the only identity with data access.
#------------------------------------------------------------------------------
resource "azurerm_linux_web_app" "api" {
  name                                           = local.names.api
  location                                       = var.location
  resource_group_name                            = var.resource_group_name
  service_plan_id                                = azurerm_service_plan.this.id
  https_only                                     = true
  client_affinity_enabled                        = false
  virtual_network_subnet_id                      = var.app_subnet_id
  ftp_publish_basic_authentication_enabled       = false
  webdeploy_publish_basic_authentication_enabled = false
  tags                                           = var.tags

  app_settings = merge(
    var.api_app_settings,
    local.api_blob_settings,
    local.api_key_vault_references,
    local.api_monitoring_settings,
    local.api_sql_settings,
  )

  identity {
    type = "SystemAssigned"
  }

  site_config {
    always_on                         = local.always_on
    http2_enabled                     = true
    minimum_tls_version               = "1.2"
    scm_minimum_tls_version           = "1.2"
    ftps_state                        = "Disabled"
    vnet_route_all_enabled            = var.app_subnet_id != null
    app_command_line                  = var.api_stack.startup_command
    health_check_path                 = var.api_health_check_path
    health_check_eviction_time_in_min = var.api_health_check_path == null ? null : 5

    application_stack {
      node_version   = var.api_stack.node_version
      dotnet_version = var.api_stack.dotnet_version
    }

    # The browser calls the API from the front end's origin.
    cors {
      allowed_origins     = concat(["https://${azurerm_linux_web_app.web.default_hostname}"], var.api_cors_allowed_origins)
      support_credentials = false
    }
  }

  lifecycle {
    precondition {
      condition     = length(local.names.api) <= 60
      error_message = "The site name ${local.names.api} is longer than 60 characters. Shorten workload or unique_suffix."
    }
  }
}

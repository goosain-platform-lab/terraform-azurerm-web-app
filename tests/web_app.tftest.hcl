# Unit tests against a mocked azurerm provider: no Azure credentials, nothing
# created. Plan runs check what is configured; apply runs also check values
# Azure would compute (IDs, principal IDs), which the mock makes up.
mock_provider "azurerm" {
  mock_data "azurerm_client_config" {
    defaults = {
      tenant_id       = "11111111-1111-1111-1111-111111111111"
      subscription_id = "22222222-2222-2222-2222-222222222222"
    }
  }
}

variables {
  workload                   = "notes"
  location                   = "southafricanorth"
  resource_group_name        = "rg-notes-lab-zan"
  log_analytics_workspace_id = "/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/rg-notes-lab-zan/providers/Microsoft.OperationalInsights/workspaces/log-notes-lab-zan"

  deploy = {
    github_repository = "example-org/notes-app"
  }
}

run "names_follow_the_convention" {
  command = plan

  assert {
    condition = (
      azurerm_service_plan.this.name == "asp-notes-lab-zan" &&
      azurerm_linux_web_app.web.name == "app-notes-web-lab-zan" &&
      azurerm_linux_web_app.api.name == "app-notes-api-lab-zan" &&
      azurerm_key_vault.this.name == "kv-notes-lab-zan" &&
      azurerm_user_assigned_identity.deploy.name == "id-notes-deploy-lab-zan" &&
      azurerm_application_insights.this.name == "appi-notes-lab-zan"
    )
    error_message = "Names must follow <type>-<workload>-<environment>-<region>."
  }
}

run "basic_auth_ftp_and_plain_http_are_off" {
  command = plan

  assert {
    condition = alltrue([
      for site in [azurerm_linux_web_app.web, azurerm_linux_web_app.api] :
      !site.ftp_publish_basic_authentication_enabled &&
      !site.webdeploy_publish_basic_authentication_enabled &&
      site.https_only &&
      site.site_config[0].ftps_state == "Disabled" &&
      site.site_config[0].minimum_tls_version == "1.2" &&
      site.site_config[0].scm_minimum_tls_version == "1.2"
    ])
    error_message = "Both sites must refuse basic authentication, FTP, plain HTTP and TLS below 1.2."
  }
}

run "secrets_are_key_vault_references_on_the_api_only" {
  command = plan

  variables {
    api_key_vault_secrets = { "Payments__ApiKey" = "payments-api-key" }
  }

  assert {
    condition     = azurerm_linux_web_app.api.app_settings["Payments__ApiKey"] == "@Microsoft.KeyVault(VaultName=kv-notes-lab-zan;SecretName=payments-api-key)"
    error_message = "A secret setting must be a Key Vault reference to this app's vault, never a value."
  }

  assert {
    condition     = !contains(try(keys(azurerm_linux_web_app.web.app_settings), []), "Payments__ApiKey")
    error_message = "The front end must not get the API's secret settings."
  }

  assert {
    condition     = azurerm_key_vault.this.rbac_authorization_enabled && azurerm_role_assignment.api_secrets_user.role_definition_name == "Key Vault Secrets User"
    error_message = "The vault must use RBAC, and the API must only be able to read secrets."
  }
}

run "blob_storage_settings_use_double_underscores" {
  command = plan

  variables {
    api_blob_storage = {
      account_name   = "stnotesdata"
      container_name = "documents"
      path_prefix    = "notes/uploads"
    }
  }

  assert {
    condition = (
      azurerm_linux_web_app.api.app_settings["BlobStorage__AccountName"] == "stnotesdata" &&
      azurerm_linux_web_app.api.app_settings["BlobStorage__ContainerName"] == "documents" &&
      azurerm_linux_web_app.api.app_settings["BlobStorage__PathPrefix"] == "notes/uploads"
    )
    error_message = "Blob storage must arrive as BlobStorage__* settings, which ASP.NET Core reads as BlobStorage:*."
  }
}

run "rejects_hand_written_blob_settings" {
  command = plan

  variables {
    api_app_settings = { "BlobStorage_PathPrefix" = "notes" }
  }

  expect_failures = [var.api_app_settings]
}

run "rejects_a_setting_that_is_both_plain_and_secret" {
  command = plan

  variables {
    api_app_settings      = { "Payments__ApiKey" = "not-a-secret-any-more" }
    api_key_vault_secrets = { "Payments__ApiKey" = "payments-api-key" }
  }

  expect_failures = [var.api_key_vault_secrets]
}

run "deploy_identity_trusts_one_repository_environment" {
  command = plan

  assert {
    condition = (
      azurerm_federated_identity_credential.github.issuer == "https://token.actions.githubusercontent.com" &&
      azurerm_federated_identity_credential.github.subject == "repo:example-org/notes-app:environment:lab" &&
      azurerm_federated_identity_credential.github.name == "github-lab"
    )
    error_message = "The deploy identity must trust only the app repository's lab Environment."
  }
}

run "deploy_identity_can_only_touch_its_own_sites" {
  command = apply

  assert {
    condition = (
      length(azurerm_role_assignment.deploy) == 2 &&
      azurerm_role_assignment.deploy["web"].scope == azurerm_linux_web_app.web.id &&
      azurerm_role_assignment.deploy["api"].scope == azurerm_linux_web_app.api.id &&
      alltrue([for grant in azurerm_role_assignment.deploy : grant.role_definition_name == "Website Contributor" && grant.principal_id == azurerm_user_assigned_identity.deploy.principal_id])
    )
    error_message = "The deploy identity must hold Website Contributor on the two sites and nothing broader."
  }

  assert {
    condition = (
      azurerm_role_assignment.api_secrets_user.principal_id == azurerm_linux_web_app.api.identity[0].principal_id &&
      azurerm_role_assignment.api_telemetry.principal_id == azurerm_linux_web_app.api.identity[0].principal_id
    )
    error_message = "Only the API's own identity reads secrets and sends telemetry."
  }

  assert {
    condition     = output.deployment_variables.AZURE_CLIENT_ID == azurerm_user_assigned_identity.deploy.client_id && output.deployment_variables.WEB_APP_NAME == "app-notes-web-lab-zan"
    error_message = "The workflow variables must name the deploy identity and the sites."
  }
}

run "vnet_integration_closes_the_vault_firewall" {
  command = plan

  variables {
    app_subnet_id               = "/subscriptions/22222222-2222-2222-2222-222222222222/resourceGroups/rg-net/providers/Microsoft.Network/virtualNetworks/vnet-notes/subnets/snet-app"
    key_vault_allowed_ip_ranges = ["203.0.113.10/32"]
  }

  assert {
    condition = (
      azurerm_key_vault.this.network_acls[0].default_action == "Deny" &&
      azurerm_linux_web_app.api.site_config[0].vnet_route_all_enabled &&
      azurerm_linux_web_app.web.site_config[0].vnet_route_all_enabled
    )
    error_message = "With a subnet, both sites route through it and the vault denies everything else."
  }
}

run "sql_is_entra_only" {
  command = plan

  variables {
    sql = {
      entra_admin_login     = "sql-admins"
      entra_admin_object_id = "33333333-3333-3333-3333-333333333333"
    }
  }

  assert {
    condition = (
      azurerm_mssql_server.this[0].azuread_administrator[0].azuread_authentication_only &&
      length(azurerm_mssql_firewall_rule.azure_services) == 1 &&
      length(azurerm_mssql_virtual_network_rule.app) == 0 &&
      contains(keys(azurerm_linux_web_app.api.app_settings), "ConnectionStrings__DefaultConnection")
    )
    error_message = "SQL must accept Entra ID sign-in only, and the API must get a passwordless connection string."
  }
}

run "rejects_a_vault_name_over_24_characters" {
  command = plan

  variables {
    workload      = "notebooks1"
    unique_suffix = "x1y2"
  }

  expect_failures = [azurerm_key_vault.this]
}

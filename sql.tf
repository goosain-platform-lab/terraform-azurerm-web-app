# Optional Azure SQL database, Entra ID authentication only: no SQL logins and
# no password anywhere. The API connects as its own identity once its database
# user exists (one T-SQL statement, see the README).
#
# Network: with app_subnet_id only the app subnet is let in (a VNet rule).
# Without a VNet, the server accepts connections from Azure services, which
# still have to sign in with Entra ID.
resource "azurerm_mssql_server" "this" {
  count = var.sql == null ? 0 : 1

  name                          = local.names.sql_server
  location                      = var.location
  resource_group_name           = var.resource_group_name
  version                       = "12.0"
  minimum_tls_version           = "1.2"
  public_network_access_enabled = true
  tags                          = var.tags

  azuread_administrator {
    login_username              = var.sql.entra_admin_login
    object_id                   = var.sql.entra_admin_object_id
    azuread_authentication_only = true
  }
}

resource "azurerm_mssql_database" "this" {
  count = var.sql == null ? 0 : 1

  name                 = local.names.sql_database
  server_id            = azurerm_mssql_server.this[0].id
  sku_name             = var.sql.sku_name
  max_size_gb          = var.sql.max_size_gb
  storage_account_type = "Local"
  tags                 = var.tags
}

resource "azurerm_mssql_virtual_network_rule" "app" {
  count = var.sql != null && var.app_subnet_id != null ? 1 : 0

  name      = "app-subnet"
  server_id = azurerm_mssql_server.this[0].id
  subnet_id = var.app_subnet_id
}

resource "azurerm_mssql_firewall_rule" "azure_services" {
  count = var.sql != null && var.app_subnet_id == null ? 1 : 0

  # 0.0.0.0 to 0.0.0.0 is Azure's marker for "Allow Azure services".
  name             = "AllowAzureServices"
  server_id        = azurerm_mssql_server.this[0].id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

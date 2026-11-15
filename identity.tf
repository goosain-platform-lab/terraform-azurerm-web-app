# The deploy identity: one per app and environment, used only by the app
# repository's GitHub Actions workflow. It has no secret: GitHub signs an OIDC
# token for each run and Entra ID accepts it only when the run is in this
# repository's GitHub Environment (see the federated credential). The
# Environment in turn accepts only the main branch, so neither another branch
# nor another repository can deploy as this identity.
#
# It can deploy to and restart its own two sites, and nothing else: no Key
# Vault, no SQL, no other site on the plan.
resource "azurerm_user_assigned_identity" "deploy" {
  name                = local.names.deploy_identity
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_federated_identity_credential" "github" {
  name                      = "github-${local.deploy_environment}"
  user_assigned_identity_id = azurerm_user_assigned_identity.deploy.id
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = "https://token.actions.githubusercontent.com"
  subject                   = local.deploy_oidc_subject
}

resource "azurerm_role_assignment" "deploy" {
  for_each = {
    web = azurerm_linux_web_app.web.id
    api = azurerm_linux_web_app.api.id
  }

  scope                = each.value
  role_definition_name = "Website Contributor"
  principal_id         = azurerm_user_assigned_identity.deploy.principal_id
  principal_type       = "ServicePrincipal"
}

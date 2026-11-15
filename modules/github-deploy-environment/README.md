# github-deploy-environment

Creates a GitHub Environment in an app repository that only the named branches can deploy from, with its non-secret workflow variables.

- **Branches:** a custom branch policy, `main` by default. Other branches and tags can't start a job that uses the Environment, so they can't get an OIDC token for it either.
- **No admin bypass:** repository admins follow the same rules.
- **Reviewers (optional):** `reviewer_teams` must approve each deployment, and the person who started the run can't approve it.
- **Variables:** for example the web-app module's `deployment_variables` (`AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`, `WEB_APP_NAME`, `API_APP_NAME`). None of them is a secret.

The provider needs **Administration** and **Variables** (read and write) on the app repository.

```hcl
module "github_environment" {
  source = "github.com/goosain-platform-lab/terraform-azurerm-web-app//modules/github-deploy-environment"

  repository            = "notes-app"
  environment           = module.web_app.deploy_environment
  environment_variables = module.web_app.deployment_variables
}
```

Tests: `terraform test` in this folder (mocked provider, no token needed).

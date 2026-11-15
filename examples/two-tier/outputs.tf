output "web_url" {
  description = "Front end URL."
  value       = module.web_app.web_app.url
}

output "api_url" {
  description = "API URL."
  value       = module.web_app.api_app.url
}

output "key_vault_name" {
  description = "Vault to put the API's secrets in."
  value       = module.web_app.key_vault.name
}

output "deploy_identity" {
  description = "The identity the app repository deploys as."
  value       = module.web_app.deploy_identity
}

output "github_environment" {
  description = "The app repository's Environment and the branches allowed to deploy from it."
  value = {
    name     = module.github_environment.environment
    branches = module.github_environment.deployment_branches
  }
}

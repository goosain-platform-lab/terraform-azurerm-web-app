output "environment" {
  description = "The Environment name, for the workflow's environment: key."
  value       = github_repository_environment.this.environment
}

output "deployment_branches" {
  description = "The branch patterns allowed to deploy."
  value       = sort(keys(github_repository_environment_deployment_policy.branch))
}

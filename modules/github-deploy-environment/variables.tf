variable "repository" {
  description = "Name of the app repository (without the owner; the provider's owner is used)."
  type        = string
}

variable "environment" {
  description = "Name of the GitHub Environment, e.g. lab. It must match the environment in the deploy identity's OIDC subject."
  type        = string
}

variable "deployment_branches" {
  description = "Branch name patterns allowed to deploy to this Environment. Every other branch, and every tag, is refused."
  type        = list(string)
  default     = ["main"]

  validation {
    condition     = length(var.deployment_branches) > 0
    error_message = "Name at least one branch: an Environment with an empty custom branch policy accepts no deployments."
  }
}

variable "reviewer_teams" {
  description = "Slugs of teams that must approve each deployment. Empty means deployments from an allowed branch need no approval."
  type        = list(string)
  default     = []
}

variable "wait_timer" {
  description = "Minutes to wait before a deployment starts (0-43200)."
  type        = number
  default     = 0

  validation {
    condition     = var.wait_timer >= 0 && var.wait_timer <= 43200
    error_message = "wait_timer must be between 0 and 43200 minutes."
  }
}

variable "environment_variables" {
  description = "Non-secret Environment variables for the deploy workflow, e.g. the web-app module's deployment_variables output."
  type        = map(string)
  default     = {}

  validation {
    condition     = alltrue([for name in keys(var.environment_variables) : can(regex("^[A-Z][A-Z0-9_]*$", name)) && !startswith(name, "GITHUB_")])
    error_message = "Variable names are UPPER_SNAKE_CASE and can't start with GITHUB_."
  }
}

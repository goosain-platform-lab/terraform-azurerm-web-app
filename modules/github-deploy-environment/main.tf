# A GitHub Environment that only the allowed branches can deploy from.
# Repository admins can't skip its rules, and with reviewers set, the person
# who started the run can't approve their own deployment.
data "github_team" "reviewer" {
  for_each = toset(var.reviewer_teams)

  slug = each.value
}

resource "github_repository_environment" "this" {
  repository          = var.repository
  environment         = var.environment
  wait_timer          = var.wait_timer
  can_admins_bypass   = false
  prevent_self_review = true

  dynamic "reviewers" {
    for_each = length(var.reviewer_teams) > 0 ? [1] : []

    content {
      teams = [for team in data.github_team.reviewer : team.id]
    }
  }

  deployment_branch_policy {
    protected_branches     = false
    custom_branch_policies = true
  }
}

resource "github_repository_environment_deployment_policy" "branch" {
  for_each = toset(var.deployment_branches)

  repository     = var.repository
  environment    = github_repository_environment.this.environment
  branch_pattern = each.value
}

resource "github_actions_environment_variable" "this" {
  for_each = var.environment_variables

  repository    = var.repository
  environment   = github_repository_environment.this.environment
  variable_name = each.key
  value         = each.value
}

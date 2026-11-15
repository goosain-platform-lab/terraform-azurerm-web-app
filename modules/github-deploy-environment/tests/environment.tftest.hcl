# Unit tests against a mocked GitHub provider: no token, nothing created.
mock_provider "github" {
  mock_data "github_team" {
    defaults = {
      id = "42"
    }
  }
}

variables {
  repository  = "notes-app"
  environment = "lab"
  environment_variables = {
    AZURE_CLIENT_ID = "00000000-0000-0000-0000-000000000000"
    WEB_APP_NAME    = "app-notes-web-lab-zan"
  }
}

run "only_main_can_deploy_and_admins_cannot_skip_it" {
  command = plan

  assert {
    condition = (
      github_repository_environment.this.deployment_branch_policy[0].custom_branch_policies &&
      !github_repository_environment.this.deployment_branch_policy[0].protected_branches &&
      toset(keys(github_repository_environment_deployment_policy.branch)) == toset(["main"]) &&
      !github_repository_environment.this.can_admins_bypass
    )
    error_message = "Only main may deploy, and repository admins must not bypass the Environment's rules."
  }

  assert {
    condition     = length(github_repository_environment.this.reviewers) == 0
    error_message = "No reviewers unless reviewer_teams is set."
  }

  assert {
    condition     = toset(keys(github_actions_environment_variable.this)) == toset(["AZURE_CLIENT_ID", "WEB_APP_NAME"])
    error_message = "Every workflow variable must be created on the Environment."
  }
}

run "reviewer_teams_must_approve" {
  command = plan

  variables {
    reviewer_teams = ["platform-owners"]
  }

  assert {
    condition = (
      contains(github_repository_environment.this.reviewers[0].teams, 42) &&
      github_repository_environment.this.prevent_self_review
    )
    error_message = "The named team must approve, and not the person who started the run."
  }
}

run "rejects_github_prefixed_variables" {
  command = plan

  variables {
    environment_variables = { GITHUB_TOKEN_NAME = "x" }
  }

  expect_failures = [var.environment_variables]
}

run "rejects_an_empty_branch_list" {
  command = plan

  variables {
    deployment_branches = []
  }

  expect_failures = [var.deployment_branches]
}

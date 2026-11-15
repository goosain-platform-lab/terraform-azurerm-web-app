terraform {
  required_version = ">= 1.9.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.14"
    }
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }

  # HCP Terraform. Organization and workspace come from the environment
  # (TF_CLOUD_ORGANIZATION / TF_WORKSPACE) so nothing tenant-specific is
  # committed. For a local-state run, delete this block.
  cloud {}
}

variable "location" {
  description = "Azure region."
  type        = string
  default     = "southafricanorth"
}

variable "workload" {
  description = "Workload token used in resource names."
  type        = string
  default     = "notes"
}

variable "environment" {
  description = "Environment token used in resource names, and the GitHub Environment name."
  type        = string
  default     = "lab"
}

variable "unique_suffix" {
  description = "Optional 0-4 character suffix if a site or vault name is taken."
  type        = string
  default     = ""
}

variable "github_owner" {
  description = "GitHub org that owns the app repository."
  type        = string
  default     = "goosain-platform-lab"
}

variable "app_repository" {
  description = "The app repository (name only) whose main branch deploys to these sites. It must already exist."
  type        = string
}

variable "secrets_officer_group_object_id" {
  description = "Entra ID group allowed to set this app's secrets in Key Vault. Null grants nobody."
  type        = string
  default     = null
}

variable "api_key_vault_secrets" {
  description = "API settings read from Key Vault: setting name => secret name."
  type        = map(string)
  default     = {}
}

variable "api_app_settings" {
  description = "Plain API settings."
  type        = map(string)
  default     = {}
}

variable "sql" {
  description = "Optional Entra-only Azure SQL database for the API. See the module's sql variable."
  type = object({
    entra_admin_login     = string
    entra_admin_object_id = string
    sku_name              = optional(string, "Basic")
    max_size_gb           = optional(number, 2)
  })
  default = null
}

variable "tags" {
  description = "Extra tags."
  type        = map(string)
  default     = {}
}

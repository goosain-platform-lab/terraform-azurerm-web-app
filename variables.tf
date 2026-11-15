#------------------------------------------------------------------------------
# Naming and placement
#------------------------------------------------------------------------------
variable "workload" {
  description = "Workload token used in resource names: <type>-<workload>-<environment>-<region>, e.g. notes."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]{2,10}$", var.workload))
    error_message = "workload must be 2-10 lowercase letters or digits."
  }
}

variable "environment" {
  description = "Environment token used in resource names, and the default GitHub Environment the deploy identity trusts."
  type        = string
  default     = "lab"

  validation {
    condition     = can(regex("^[a-z0-9]{2,8}$", var.environment))
    error_message = "environment must be 2-8 lowercase letters or digits."
  }
}

variable "location" {
  description = "Azure region for every resource."
  type        = string
}

variable "unique_suffix" {
  description = "Optional 0-4 character suffix for globally unique names (the sites, Key Vault and SQL server)."
  type        = string
  default     = ""

  validation {
    condition     = can(regex("^[a-z0-9]{0,4}$", var.unique_suffix))
    error_message = "unique_suffix must be 0-4 lowercase letters or digits."
  }
}

variable "resource_group_name" {
  description = "Existing resource group for every resource."
  type        = string
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default     = {}
}

#------------------------------------------------------------------------------
# Hosting
#------------------------------------------------------------------------------
variable "app_service_plan_sku" {
  description = "Linux App Service plan SKU shared by both sites, e.g. B1, P0v3, P1v3."
  type        = string
  default     = "B1"
}

variable "web_stack" {
  description = "Runtime of the front end. Set node_version or dotnet_version. The default serves a static single-page app (such as Blazor WebAssembly output) with pm2."
  type = object({
    node_version    = optional(string)
    dotnet_version  = optional(string)
    startup_command = optional(string)
  })
  default = {
    node_version    = "22-lts"
    startup_command = "pm2 serve /home/site/wwwroot --no-daemon --spa"
  }

  validation {
    condition     = (var.web_stack.node_version == null) != (var.web_stack.dotnet_version == null)
    error_message = "web_stack must set exactly one of node_version or dotnet_version."
  }
}

variable "api_stack" {
  description = "Runtime of the API. Set dotnet_version or node_version."
  type = object({
    node_version    = optional(string)
    dotnet_version  = optional(string)
    startup_command = optional(string)
  })
  default = {
    dotnet_version = "10.0"
  }

  validation {
    condition     = (var.api_stack.node_version == null) != (var.api_stack.dotnet_version == null)
    error_message = "api_stack must set exactly one of node_version or dotnet_version."
  }
}

variable "api_health_check_path" {
  description = "Path App Service probes on the API, e.g. /healthz. Null turns health checks off."
  type        = string
  default     = null

  validation {
    condition     = var.api_health_check_path == null || startswith(coalesce(var.api_health_check_path, "/"), "/")
    error_message = "api_health_check_path must start with /."
  }
}

variable "api_cors_allowed_origins" {
  description = "Origins allowed to call the API from a browser, besides the front end, which is always allowed."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for origin in var.api_cors_allowed_origins : can(regex("^https://[^/*]+$", origin))])
    error_message = "api_cors_allowed_origins must be https origins without a path or wildcard, e.g. https://notes.example.com."
  }
}

variable "app_subnet_id" {
  description = "Subnet for regional VNet integration of both sites (delegated to Microsoft.Web/serverFarms, with the Microsoft.KeyVault and Microsoft.Sql service endpoints). Null keeps the sites off any VNet; see the README for what that means for Key Vault and SQL."
  type        = string
  default     = null
}

#------------------------------------------------------------------------------
# Settings. App Service on Linux can't use ":" in a setting name, so nested
# configuration keys use "__" (BlobStorage__ContainerName is
# BlobStorage:ContainerName to ASP.NET Core). A single "_" is not translated.
#------------------------------------------------------------------------------
variable "web_app_settings" {
  description = "Plain (non-secret) app settings for the front end."
  type        = map(string)
  default     = {}

  validation {
    condition     = alltrue([for name in keys(var.web_app_settings) : can(regex("^[A-Za-z0-9_.-]+$", name))])
    error_message = "App setting names may only hold letters, digits, '_', '.' and '-'. Use '__' for nested keys, not ':'."
  }
}

variable "api_app_settings" {
  description = "Plain (non-secret) app settings for the API. Secrets go in api_key_vault_secrets and blob storage in api_blob_storage, so they can't be set here."
  type        = map(string)
  default     = {}

  validation {
    condition     = alltrue([for name in keys(var.api_app_settings) : can(regex("^[A-Za-z0-9_.-]+$", name))])
    error_message = "App setting names may only hold letters, digits, '_', '.' and '-'. Use '__' for nested keys, not ':'."
  }

  validation {
    condition     = alltrue([for name in keys(var.api_app_settings) : !startswith(name, "BlobStorage_") && !startswith(name, "APPLICATIONINSIGHTS_") && name != "ConnectionStrings__DefaultConnection"])
    error_message = "BlobStorage_*, APPLICATIONINSIGHTS_* and ConnectionStrings__DefaultConnection are set by the module (api_blob_storage, monitoring, sql). Remove them from api_app_settings."
  }
}

variable "api_key_vault_secrets" {
  description = "API settings whose values live in this app's Key Vault: setting name => secret name, e.g. { \"Payments__ApiKey\" = \"payments-api-key\" }. The API reads them as Key Vault references; the values never pass through Terraform."
  type        = map(string)
  default     = {}

  validation {
    condition     = alltrue([for secret in values(var.api_key_vault_secrets) : can(regex("^[0-9A-Za-z-]{1,127}$", secret))])
    error_message = "Key Vault secret names are 1-127 letters, digits and hyphens."
  }

  validation {
    condition     = alltrue([for name in keys(var.api_key_vault_secrets) : can(regex("^[A-Za-z0-9_.-]+$", name))])
    error_message = "App setting names may only hold letters, digits, '_', '.' and '-'. Use '__' for nested keys, not ':'."
  }

  validation {
    condition     = length(setintersection(keys(var.api_key_vault_secrets), keys(var.api_app_settings))) == 0
    error_message = "A setting can't be both a plain value in api_app_settings and a secret in api_key_vault_secrets."
  }
}

variable "api_blob_storage" {
  description = "Existing storage the API uses, written as the BlobStorage__AccountName, __ContainerName and __PathPrefix settings. The module grants no access: give the API's identity a data role or folder ACLs yourself (see the README)."
  type = object({
    account_name   = string
    container_name = string
    path_prefix    = optional(string)
  })
  default = null

  validation {
    condition     = var.api_blob_storage == null ? true : can(regex("^[a-z0-9]{3,24}$", var.api_blob_storage.account_name))
    error_message = "api_blob_storage.account_name must be 3-24 lowercase letters or digits."
  }

  validation {
    condition = var.api_blob_storage == null ? true : (
      can(regex("^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$", var.api_blob_storage.container_name)) &&
      !strcontains(var.api_blob_storage.container_name, "--")
    )
    error_message = "api_blob_storage.container_name must be 3-63 lowercase letters, digits and single hyphens, starting and ending with a letter or digit."
  }

  validation {
    condition = var.api_blob_storage == null ? true : (
      var.api_blob_storage.path_prefix == null ||
      can(regex("^[A-Za-z0-9._-]+(/[A-Za-z0-9._-]+)*$", coalesce(var.api_blob_storage.path_prefix, "x")))
    )
    error_message = "api_blob_storage.path_prefix is a folder path without leading or trailing '/', e.g. notes or notes/uploads."
  }
}

#------------------------------------------------------------------------------
# Key Vault, monitoring, database
#------------------------------------------------------------------------------
variable "key_vault_secrets_officer_principal_ids" {
  description = "Object IDs (preferably groups) allowed to set this app's secret values. Nobody else, including Terraform, writes secrets."
  type        = list(string)
  default     = []
}

variable "key_vault_allowed_ip_ranges" {
  description = "Public IP ranges (CIDR) that may reach Key Vault when app_subnet_id is set and the vault firewall is on, e.g. the address you set secrets from."
  type        = list(string)
  default     = []
}

variable "key_vault_purge_protection_enabled" {
  description = "Keep deleted vaults and secrets recoverable for the retention period. Off by default because lab environments are destroyed and redeployed; turn it on for anything long-lived."
  type        = bool
  default     = false
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics workspace for Application Insights and the diagnostic settings."
  type        = string
}

variable "sql" {
  description = "Optional Azure SQL database for the API, Entra ID authentication only. The admin is a group (recommended) or user; the API's own database user is created once with T-SQL (see the README)."
  type = object({
    entra_admin_login     = string
    entra_admin_object_id = string
    sku_name              = optional(string, "Basic")
    max_size_gb           = optional(number, 2)
  })
  default = null
}

#------------------------------------------------------------------------------
# Deployment from GitHub Actions
#------------------------------------------------------------------------------
variable "deploy" {
  description = "The app repository allowed to deploy: github_repository as owner/name, and the GitHub Environment it deploys from (default: var.environment). Set oidc_subject only if your org customised its OIDC subject template."
  type = object({
    github_repository = string
    environment       = optional(string)
    oidc_subject      = optional(string)
  })

  validation {
    condition     = can(regex("^[A-Za-z0-9-]+/[A-Za-z0-9._-]+$", var.deploy.github_repository))
    error_message = "deploy.github_repository must be owner/name, e.g. my-org/notes-app."
  }
}

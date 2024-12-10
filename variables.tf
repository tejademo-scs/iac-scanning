variable "key_vault" {
  type        = string
  description = "Key Vault Name"

  validation {
    condition     = length(var.key_vault) >= 3 && length(var.key_vault) <= 24
    error_message = "The length of the key vault name should be between 3-24 characters"
  }
}

variable "location" {
  type        = string
  description = "Key Vault Location"
}

variable "resource_group" {
  type        = string
  description = "Resource Group in which KeyVault will be deployed"
}

variable "tenant_id" {
  description = "Azure Active Directory tenant ID that should be used for authenticating requests to the key vault"
}

variable "tags" {
  type        = map(any)
  default     = {}
  description = "Custom tags for Key Vault"
}

variable "key_vault_keys" {
  type = list(object({
    name     = string
    key_opts = list(string)
    key_size = number
    key_type = string
  }))
  default = []
}

variable "key_vault_secrets" {
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}

variable "group_access_policies" {
  description = "Set access policies for user groups"
  type = list(object({
    access_group       = string
    key_permissions    = list(string),
    secret_permissions = list(string),
  }))
  default = []
}

variable "principal_access_policies" {
  description = "Set access policies for user groups"
  type = list(object({
    principal_id       = string
    key_permissions    = list(string),
    secret_permissions = list(string),
  }))
  default = []
}

variable "principal_name_access_policies" {
  description = "Set access policies for service principal based on name"
  type = list(object({
    principal_name     = string
    key_permissions    = list(string),
    secret_permissions = list(string),
  }))
  default = []
}

variable "subnet_ids" {
  type    = list(string)
  default = []
}

variable "ip_rules" {
  type    = list(string)
  default = []
}

variable "default_action" {
  type    = string
  default = "Deny"
}

variable "soft_delete_retention_days" {
  type    = number
  default = 90
}

variable "purge_protection_enabled" {
  type    = bool
  default = true
}

variable "enabled_for_disk_encryption" {
  type    = bool
  default = false
}

variable "key_vault_secrets_tags" {
  type = map(any)
  default = {
    tag = "terraform"
  }
  description = "Custom tags for Key Vault Secrets"
}

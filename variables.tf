variable "default_action" {
   type = string
   default = "Deny"
}

variable "soft_delete_retention_days" {
   type = number
   default = 90
}

variable "purge_protection_enabled" {
   type = bool
   default = true
}

variable "enabled_for_disk_encryption" {
   type = bool
   default = false
}

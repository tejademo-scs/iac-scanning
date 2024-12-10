resource "azurerm_key_vault" "key_vault" {
  name                        = var.key_vault
  location                    = var.location
  resource_group_name         = var.resource_group
  tenant_id                   = var.tenant_id
  sku_name                    = "standard"
  soft_delete_retention_days  = var.soft_delete_retention_days
  purge_protection_enabled    = var.purge_protection_enabled
  enabled_for_disk_encryption = var.enabled_for_disk_encryption
  tags                        = var.tags
  network_acls {
    bypass                     = "AzureServices"
    default_action             = var.default_action
    ip_rules                   = var.ip_rules
    virtual_network_subnet_ids = var.subnet_ids
  }
  timeouts {
    create = "15m"
    update = "15m"
    delete = "15m"
  }
}

data "azuread_group" "access_groups" {
  count            = length(var.group_access_policies)
  display_name     = var.group_access_policies[count.index].access_group
  security_enabled = true
}

resource "azurerm_key_vault_access_policy" "access_groups_access" {
  count              = length(var.group_access_policies)
  key_vault_id       = azurerm_key_vault.key_vault.id
  tenant_id          = var.tenant_id
  object_id          = data.azuread_group.access_groups[count.index].object_id
  key_permissions    = var.group_access_policies[count.index].key_permissions
  secret_permissions = var.group_access_policies[count.index].secret_permissions
  timeouts {
    create = "10m"
    update = "10m"
    delete = "10m"
  }
}

resource "azurerm_key_vault_access_policy" "principals_access" {
  count              = length(var.principal_access_policies)
  key_vault_id       = azurerm_key_vault.key_vault.id
  tenant_id          = var.tenant_id
  object_id          = var.principal_access_policies[count.index].principal_id
  key_permissions    = var.principal_access_policies[count.index].key_permissions
  secret_permissions = var.principal_access_policies[count.index].secret_permissions
  timeouts {
    create = "10m"
    update = "10m"
    delete = "10m"
  }
}

data "azurerm_subscription" "current" {}
# Azure DevOps Organization/Project CCHBC-CCH SAFe Portfolio
# CCHBC Data Mesh Production:  CCHBC-CCH SAFe Portfolio-b4e2f63b-382e-4038-b35c-203e0e3e88a0 - (objectId: 2bcbfcf9-2609-482c-af98-29aefc4dfd3e)
# CCHBC Data Mesh Development: CCHBC-CCH SAFe Portfolio-583a2800-5353-4684-9d63-93c2e8ee3391 - (ObjectId: 740d22ce-cd6f-4f6f-a1a1-22409aa3d816)
resource "azurerm_key_vault_access_policy" "devops_access" {
  key_vault_id       = azurerm_key_vault.key_vault.id
  tenant_id          = var.tenant_id
  object_id          = data.azurerm_subscription.current.display_name == "CCHBC Data Mesh Production" ? "2bcbfcf9-2609-482c-af98-29aefc4dfd3e" : "740d22ce-cd6f-4f6f-a1a1-22409aa3d816"
  secret_permissions = ["Get", "List"]
  timeouts {
    create = "10m"
    update = "10m"
    delete = "10m"
  }
}

data "azuread_service_principal" "main" {
  for_each     = { for item in var.principal_name_access_policies != null ? var.principal_name_access_policies : [] : item.principal_name => item }
  display_name = each.key
}

resource "azurerm_key_vault_access_policy" "sp" {
  for_each           = { for item in var.principal_name_access_policies != null ? var.principal_name_access_policies : [] : item.principal_name => item }
  key_vault_id       = azurerm_key_vault.key_vault.id
  object_id          = data.azuread_service_principal.main[each.key].object_id
  tenant_id          = var.tenant_id
  secret_permissions = each.value.secret_permissions
  key_permissions    = each.value.key_permissions
}

# Redeployment must happed > 100 days before end of year to update secrets validity 
locals {
  expiration_date = "${formatdate("YYYY", timeadd(plantimestamp(), "2400h"))}-12-31T00:00:00Z"
}

resource "azurerm_key_vault_key" "key_vault_key" {
  depends_on      = [azurerm_key_vault_access_policy.principals_access, azurerm_key_vault_access_policy.access_groups_access]
  count           = length(var.key_vault_keys)
  name            = var.key_vault_keys[count.index].name
  key_vault_id    = azurerm_key_vault.key_vault.id
  key_type        = var.key_vault_keys[count.index].key_type
  key_size        = var.key_vault_keys[count.index].key_size
  key_opts        = var.key_vault_keys[count.index].key_opts
  expiration_date = local.expiration_date
  timeouts {
    create = "10m"
    update = "10m"
    delete = "10m"
  }
}

resource "azurerm_key_vault_secret" "key_vault_secret" {
  depends_on      = [azurerm_key_vault_access_policy.principals_access, azurerm_key_vault_access_policy.access_groups_access]
  count           = length(var.key_vault_secrets)
  key_vault_id    = azurerm_key_vault.key_vault.id
  content_type    = "secret" # TODO maybe param ? 
  name            = var.key_vault_secrets[count.index].name
  value           = var.key_vault_secrets[count.index].value
  tags            = var.key_vault_secrets_tags
  expiration_date = local.expiration_date
  lifecycle {
    ignore_changes = [timeouts]
  }
}

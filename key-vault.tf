resource "azurerm_key_vault" "key_vault" {
  name                = test-keyvault321
  location            = var.location
  resource_group_name = var.resource_group_name
  tenant_id           = var.tenant_id
  sku_name            = "standard"
  soft_delete_retention_days = var.soft_delete_retention_days
  purge_protection_enabled = var.purge_protection_enabled
  enabled_for_disk_encryption = var.enabled_for_disk_encryption
  tags                = var.tags

  network_acls {
    bypass                = "AzureServices"
    default_action        = var.default_action
  }


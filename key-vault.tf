resource "azurerm_key_vault" "key_vault" {
  name                = var.key_vault_name
  location            = var.location
  resource_group_name = var.resource_group_name
  tenant_id           = var.tenant_id
  sku_name            = "standard"
  tags                = var.tags

  network_acls {
    bypass                = "AzureServices"
    default_action        = var.default_action
    ip_rules              = var.ip_rules
    virtual_network_subnet_ids = var.subnet_ids
  }

  timeouts {
    create = "15m"
    update = "15m"
    delete = "15m"
  }
}

data "azurerm_client_config" "current" {}

resource "random_pet" "rg_name" {
  prefix = var.resource_group_name_prefix
}

# create a resource group
resource "azurerm_resource_group" "rg" {
  location = var.resource_group_location
  name     = random_pet.rg_name.id
}

# Network Config
# create a virtual network
resource "azurerm_virtual_network" "AIvnet" {
  name                = "ai-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# create a subnet for the private endpoints
resource "azurerm_subnet" "PEsubnet" {
  name                 = "pe-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.AIvnet.name
  address_prefixes     = ["10.0.1.0/24"]
  #remove this service endpoint after the network configuration is complete on the storage account
  service_endpoints = ["Microsoft.Storage", "Microsoft.CognitiveServices"]

}

# create an NSG for the PE subnet
resource "azurerm_network_security_group" "pe-nsg" {
  name                = "PE-NSG"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "AllowFunctionInbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = azurerm_subnet.integrationsubnet.address_prefixes[0]
    destination_address_prefix = azurerm_subnet.PEsubnet.address_prefixes[0]
  }
}

# associate NSG with the subnet
resource "azurerm_subnet_network_security_group_association" "pe_subnet_nsg" {
  subnet_id                 = azurerm_subnet.PEsubnet.id
  network_security_group_id = azurerm_network_security_group.pe-nsg.id
}

# Create a subnet for fa network integration with delegation
resource "azurerm_subnet" "integrationsubnet" {
  name                 = "IntegrationSubnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.AIvnet.name
  address_prefixes     = ["10.0.2.0/24"]
  #remove this service endpoint after the network configuration is complete on the storage account
  service_endpoints    = ["Microsoft.Storage"]

  delegation {
    name = "delegation"
    service_delegation {
      name = "Microsoft.Web/serverFarms"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action",
      ]
    }
  }
}

# create an NSG for the function app subnet
resource "azurerm_network_security_group" "fa-nsg" {
  name                = "FA-NSG"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "AllowFunctionOutbound"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = azurerm_subnet.PEsubnet.address_prefixes[0]
    destination_address_prefix = azurerm_subnet.integrationsubnet.address_prefixes[0]
  }
}

# associate NSG with the subnet
resource "azurerm_subnet_network_security_group_association" "integration_subnet_nsg" {
  subnet_id                 = azurerm_subnet.integrationsubnet.id
  network_security_group_id = azurerm_network_security_group.fa-nsg.id
}

# Storage Account config
# create a storage account with network rules
resource "azurerm_storage_account" "AIstore" {
  name                     = "aidocstorageacct59"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
    network_rules {
    default_action = "Deny"
    virtual_network_subnet_ids = [
      azurerm_subnet.PEsubnet.id,
      azurerm_subnet.integrationsubnet.id
    ]
  }
}

# create a container in the storage account
resource "azurerm_storage_container" "container" {
  name                  = "images"
  storage_account_id    = azurerm_storage_account.AIstore.id
  container_access_type = "private"
}

# create a private endpoint for the storage account containers
resource "azurerm_private_endpoint" "storagepe" {
  name                = "storage-pe"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = azurerm_subnet.PEsubnet.id

  private_service_connection {
    name                           = "storage-psc"
    private_connection_resource_id = azurerm_storage_account.AIstore.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                = "blobdnsgroup"
    private_dns_zone_ids = [azurerm_private_dns_zone.blob_dns_zone.id]
  }
}

# create a table in the storage account
resource "azurerm_storage_table" "table" {
  name                 = "imagetext"
  storage_account_name = azurerm_storage_account.AIstore.name
}

# create a private endpoint for the storage account tables
resource "azurerm_private_endpoint" "tablepe" {
  name                = "table-pe"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = azurerm_subnet.PEsubnet.id

  private_service_connection {
    name                           = "table-psc"
    private_connection_resource_id = azurerm_storage_account.AIstore.id
    subresource_names              = ["table"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                = "tablednsgroup"
    private_dns_zone_ids = [azurerm_private_dns_zone.table_dns_zone.id]
  }
}

# AI deployment config
# create an azure computer vision account
resource "azurerm_cognitive_account" "AIvision" {
  name                = "cognitiveCVaccountvinnysdemo59"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  kind                = "ComputerVision"
  sku_name            = "S1"
  identity {
    type = "SystemAssigned"
  }
  custom_subdomain_name = "computervisionvinnysdemo59"
  network_acls {
    default_action = "Deny"
    virtual_network_rules {
        subnet_id = azurerm_subnet.PEsubnet.id
    }
  }
}

# create a private endpoint for the computer vision service
resource "azurerm_private_endpoint" "visionpe" {
  name                = "vision-pe"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = azurerm_subnet.PEsubnet.id

  private_service_connection {
    name                           = "vision-psc"
    private_connection_resource_id = azurerm_cognitive_account.AIvision.id
    subresource_names              = ["account"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                = "aidnsgroup"
    private_dns_zone_ids = [azurerm_private_dns_zone.vision_dns_zone.id]
  }
}

# Function App config
# create an app service plan
resource "azurerm_service_plan" "asp" {
  name                = "AIFunctionASP"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  os_type             = "Windows"
  sku_name            = "P1v2"  # PremiumV2 plan
}

# Create a Function App (check config for the function requirements)
resource "azurerm_windows_function_app" "fa" {
  name                       = "AIFunctionAppVinny59"
  location                   = azurerm_resource_group.rg.location
  resource_group_name        = azurerm_resource_group.rg.name
  service_plan_id            = azurerm_service_plan.asp.id
  storage_account_name       = azurerm_storage_account.AIstore.name
  functions_extension_version = "~4"
  app_settings = {
    "FUNCTIONS_WORKER_RUNTIME" = "dotnet-isolated"
    "WEBSITE_RUN_FROM_PACKAGE" = "1"
    "StorageConnection" = "@Microsoft.KeyVault(SecretUri=https://aikeyvault59.vault.azure.net/secrets/storageAccountName)"
    "ComputerVisionKey" = "@Microsoft.KeyVault(SecretUri=https://aikeyvault59.vault.azure.net/secrets/computerVisionKey)"
    "ComputerVisionEndpoint" = azurerm_cognitive_account.AIvision.endpoint
    "StorageAccountName" = azurerm_storage_account.AIstore.name
    "StorageAccountKey" = "@Microsoft.KeyVault(SecretUri=https://aikeyvault59.vault.azure.net/secrets/storageAccountKey)"
    "AzureWebJobsStorage" = "@Microsoft.KeyVault(SecretUri=https://aikeyvault59.vault.azure.net/secrets/webjobStoreConnectionString)"
  }
  identity {
    type = "SystemAssigned"
  }
  site_config {
    #application_insights_connection_string = "@Microsoft.KeyVault(SecretUri=https://aikeyvault46.vault.azure.net/secrets/appInsightsConnectionString)"
    application_stack {
      dotnet_version = "v8.0"
      use_dotnet_isolated_runtime = true
    }
  }
}

# Create private endpoints for Function App
resource "azurerm_private_endpoint" "pe_function" {
  name                = "pe-aifunction"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = azurerm_subnet.PEsubnet.id
  
  private_service_connection {
    name                           = "aifunctionConnection"
    private_connection_resource_id = azurerm_windows_function_app.fa.id
    subresource_names              = ["sites"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                = "fadnsgroup"
    private_dns_zone_ids = [azurerm_private_dns_zone.fa_dns_zone.id]
  }
}

# Enable Virtual Network Integration for the Function App
resource "azurerm_app_service_virtual_network_swift_connection" "vnet_integration" {
  app_service_id    = azurerm_windows_function_app.fa.id
  subnet_id         = azurerm_subnet.integrationsubnet.id
}

# App Insights (if needed)
# Create an Application Insights instance
#resource "azurerm_application_insights" "app_insights" {
#  name                = "AIFunctionAppInsights"
#  location            = azurerm_resource_group.rg.location
#  resource_group_name = azurerm_resource_group.rg.name
#  application_type    = "web"
#}

# create AMPLS for App Insights
#resource "azurerm_monitor_private_link_scope" "ampls" {
#  name                = "myAMPLSai"
#  resource_group_name = azurerm_resource_group.rg.name
#}

# Link App Insights to AMPLS
#resource "azurerm_monitor_private_link_scoped_service" "app_insights_link" {
#  name                          = "appInsightsLinkai"
#  resource_group_name           = azurerm_resource_group.rg.name
#  scope_name = azurerm_monitor_private_link_scope.ampls.name
#  linked_resource_id    = azurerm_application_insights.app_insights.id
#}

# Create a PE for AMPLS
#resource "azurerm_private_endpoint" "pe_ampls" {
#  name                = "pe-amplsai"
#  location            = azurerm_resource_group.rg.location
#  resource_group_name = azurerm_resource_group.rg.name
#  subnet_id           = azurerm_subnet.PEsubnet.id
#
#  private_service_connection {
#    name                           = "amplsConnectionai"
#    private_connection_resource_id = azurerm_monitor_private_link_scope.ampls.id
#    subresource_names              = ["azuremonitor"]
#    is_manual_connection           = false
#  }

#  private_dns_zone_group {
#    name                = "aidnsgroup"
#    private_dns_zone_ids = [azurerm_private_dns_zone.pe.id]
#  }
#}

# Key Vault configuration
# create a key vault
resource "azurerm_key_vault" "kv" {
  name                = "aiKeyVault59"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku_name            = "standard"
  tenant_id           = var.tenant_id
}

# create a private endpoint for the key vault
resource "azurerm_private_endpoint" "pe_kv" {
  name                = "pe-kv"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = azurerm_subnet.PEsubnet.id

  private_service_connection {
    name                           = "kvConnection"
    private_connection_resource_id = azurerm_key_vault.kv.id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                = "kvdnsgroup"
    private_dns_zone_ids = [azurerm_private_dns_zone.kv_dns_zone.id]
  }
}

# access policy for the current user to create secrets in the key vault (NOTE: Remove or reduce this access in production)
resource "azurerm_key_vault_access_policy" "kv_access_policy" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = var.tenant_id
  object_id    = data.azurerm_client_config.current.object_id
  secret_permissions = [
    "Get", "List", "Set", "Delete", "Purge" # Reduce this list as needed for least privilege
  ]
}

# access policy for the function app to get secrets from the key vault
resource "azurerm_key_vault_access_policy" "fa_access_policy" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = var.tenant_id
  object_id    = azurerm_windows_function_app.fa.identity[0].principal_id
  secret_permissions = [
    "Get"
  ]
}

# add Keys to Key Vault

# create a secret for the app insights connection string
#resource "azurerm_key_vault_secret" "app_insights_connection_string" {
#  name         = "appInsightsConnectionString"
#  value        = azurerm_application_insights.app_insights.connection_string
#  key_vault_id = azurerm_key_vault.kv.id
#}

# create a secret for the storage account connection string
resource "azurerm_key_vault_secret" "webjobStoreConnectionString" {
  name         = "webjobStoreConnectionString"
  value        = azurerm_storage_account.AIstore.primary_connection_string
  key_vault_id = azurerm_key_vault.kv.id
}

# create a secret for the storage account key
resource "azurerm_key_vault_secret" "storageAccountKey" {
  name         = "storageAccountKey"
  value        = azurerm_storage_account.AIstore.primary_access_key
  key_vault_id = azurerm_key_vault.kv.id
}

# create a secret for the computer vision key
resource "azurerm_key_vault_secret" "computer_vision_key" {
  name         = "computerVisionKey"
  value        = azurerm_cognitive_account.AIvision.primary_access_key
  key_vault_id = azurerm_key_vault.kv.id
}

# create a secret for the storage account
resource "azurerm_key_vault_secret" "StorageConnection" {
  name         = "storageAccountName"
  value        = azurerm_storage_account.AIstore.primary_connection_string
  key_vault_id = azurerm_key_vault.kv.id
}

# DNS config
# Create a Private DNS Zone for the function app
resource "azurerm_private_dns_zone" "fa_dns_zone" {
  name                = "privatelink.azurewebsites.net"
  resource_group_name = azurerm_resource_group.rg.name
}

# Link the Function DNS Zone to the virtual network
resource "azurerm_private_dns_zone_virtual_network_link" "fa_dns_link" {
  name                  = "fa-dns-link"
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.fa_dns_zone.name
  virtual_network_id    = azurerm_virtual_network.AIvnet.id
}

# Create a Private DNS Zone for the storage blob
resource "azurerm_private_dns_zone" "blob_dns_zone" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = azurerm_resource_group.rg.name
}

# Link the Storage DNS Zone to the virtual network
resource "azurerm_private_dns_zone_virtual_network_link" "storage_dns_link" {
  name                  = "storage-dns-link"
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.blob_dns_zone.name
  virtual_network_id    = azurerm_virtual_network.AIvnet.id
}

# Create a Private DNS Zone for the storage table
resource "azurerm_private_dns_zone" "table_dns_zone" {
  name                = "privatelink.table.core.windows.net"
  resource_group_name = azurerm_resource_group.rg.name
}

# Link the Table DNS Zone to the virtual network
resource "azurerm_private_dns_zone_virtual_network_link" "table_dns_link" {
  name                  = "table-dns-link"
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.table_dns_zone.name
  virtual_network_id    = azurerm_virtual_network.AIvnet.id
}

# Create a Private DNS Zone for the computer vision service
resource "azurerm_private_dns_zone" "vision_dns_zone" {
  name                = "privatelink.cognitiveservices.azure.com"
  resource_group_name = azurerm_resource_group.rg.name
}

# Link the Vision DNS Zone to the virtual network
resource "azurerm_private_dns_zone_virtual_network_link" "vision_dns_link" {
  name                  = "vision-dns-link"
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.vision_dns_zone.name
  virtual_network_id    = azurerm_virtual_network.AIvnet.id
}

# Create a Private DNS Zone for the Key Vault
resource "azurerm_private_dns_zone" "kv_dns_zone" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = azurerm_resource_group.rg.name
}

# Link the Key Vault DNS Zone to the virtual network
resource "azurerm_private_dns_zone_virtual_network_link" "kv_dns_link" {
  name                  = "kv-dns-link"
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.kv_dns_zone.name
  virtual_network_id    = azurerm_virtual_network.AIvnet.id
}

# managed identities config
# create a managed identity role for the function to access the storage account
resource "azurerm_role_assignment" "Functionstorageaccess" {
  scope                = azurerm_storage_account.AIstore.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_windows_function_app.fa.identity[0].principal_id
}

# create a role for the current user to access the storage account
resource "azurerm_role_assignment" "userStorageaccess" {
  scope                = azurerm_storage_account.AIstore.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}

# create a role to make the current user the owner of the storage account (NOTE: Remove this role in production)
resource "azurerm_role_assignment" "StorageContributor" {
  scope                = azurerm_storage_account.AIstore.id
  role_definition_name = "Storage Account Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}

# create a role for the current user to access the AI
resource "azurerm_role_assignment" "userAIaccess" {
  scope                = azurerm_cognitive_account.AIvision.id
  role_definition_name = "Cognitive Services Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}

# create a role for the computer vision service to access the storage account
resource "azurerm_role_assignment" "AIstorageaccess" {
  scope                = azurerm_storage_account.AIstore.id
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = azurerm_cognitive_account.AIvision.identity[0].principal_id
}

# create a role for the user to view the table in the storage account
resource "azurerm_role_assignment" "userTableaccess" {
  scope                = azurerm_storage_table.table.id
  role_definition_name = "Storage Table Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}

# create a role for the function app to access the table in the storage account
resource "azurerm_role_assignment" "FAstorageTableaccess" {
  scope                = azurerm_storage_table.table.id
  role_definition_name = "Storage Table Data Contributor"
  principal_id         = azurerm_windows_function_app.fa.identity[0].principal_id
}

# managed identity role for the function app connection to app insights
#resource "azurerm_role_assignment" "app_insights_monitoring_publisher" {
#  scope                = azurerm_application_insights.app_insights.id
#  role_definition_name = "Monitoring Metrics Publisher"
#  principal_id         = azurerm_windows_function_app.fa.identity[0].principal_id
#}

#resource "azurerm_role_assignment" "app_insights_monitoring_contributor" {
#  scope                = azurerm_application_insights.app_insights.id
#  role_definition_name = "Monitoring Contributor"
#  principal_id         = azurerm_windows_function_app.fa.identity[0].principal_id
#}
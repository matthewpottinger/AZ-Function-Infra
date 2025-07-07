variable "tenant_id" {
  default     = "b8b1a417-b513-4ed6-a686-93da9f842a7e"
  description = "The Tenant ID for Azure"
  type        = string
}

variable "subscription_id" {
  default     = "43559797-46d3-45a2-bc18-d03ced80f12b"
  description = "The Subscription ID for Azure"
  type        = string
}

variable "resource_group_location" {
  default     = "uksouth"
  description = "Location of the resource group."
  type        = string
}

variable "resource_group_name" {
  default     = "vsemmplabai-rg"
  description = "Prefix of the resource group name that's combined with a random ID so name is unique in your Azure subscription."
  type        = string
}

variable "storage_account_name" {
  default     = "vsemplabssaai"
  description = "The name of the storage account to be created."
  type        = string
}

variable "app_service_plan_name" {
  default     = "AIFunctionASP"
  description = "The name of the App Service Plan to be created."
  type        = string
}

variable "function_app_name" {   
  default     = "TTextToSpeechFunction"
  description = "The name of the Azure Function to be created."
  type        = string
}

variable "key_vault_name" { 
  default     = "vsemplabskvai"
  description = "The name of the Azure key vault to be created."       
  type        = string
}

variable "cognitive_account_name" { 
  default     = "vsemplabcogai"
  description = "The name of the Cognitive Services account to be created." 
  type        = string
}

variable "tenant_id" {
  default = "<TENANT ID>"
  description = "The Tenant ID for Azure"
  type        = string
}

variable "subscription_id" {
  default = "<SUB ID>"
  description = "The Subscription ID for Azure"
  type        = string
}

variable "resource_group_location" {
  default     = "uksouth"
  description = "Location of the resource group."
}

variable "resource_group_name_prefix" {
  default     = "rg"
  description = "Prefix of the resource group name that's combined with a random ID so name is unique in your Azure subscription."
}
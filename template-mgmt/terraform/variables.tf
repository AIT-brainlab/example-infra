variable "project_id" {
  type        = string
  description = "GCP Project ID for Domain Management Plane (<domain>-mgmt)"
}

variable "region" {
  type        = string
  description = "GCP Region for Domain Management Plane resources"
  default     = "asia-southeast1"
}

variable "domain_name" {
  type        = string
  description = "Domain name for Cloud DNS (must end with dot, e.g. example.com.). Leave empty if not using Cloud DNS."
  default     = ""
}

variable "domain_slug" {
  type        = string
  description = "Domain slug identifier (e.g. ait-vc, mosip-asia)"
  default     = ""
}

# --- Project & Team Variables ---

variable "project_admins" {
  type        = list(string)
  description = "List of administrator emails granted Editor access to the management project"
  default     = []
}

variable "project_members" {
  type        = list(string)
  description = "List of viewer emails granted Viewer access to the management project"
  default     = []
}

variable "billing_account_id" {
  type        = string
  description = "Authoritative Google Cloud Billing Account ID"
  default     = ""
}

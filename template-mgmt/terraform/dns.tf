# ==========================================================
# 🌐 Optional Cloud DNS Managed Zone
# ==========================================================
# Only provisioned if var.domain_name is provided.
# ==========================================================

# Required GCP APIs for Cloud DNS (only enabled if domain_name is provided)
resource "google_project_service" "dns_api" {
  count              = var.domain_name != "" ? 1 : 0
  project            = var.project_id
  service            = "dns.googleapis.com"
  disable_on_destroy = false
}

# Managed DNS Zone (only created if domain_name is provided)
resource "google_dns_managed_zone" "domain_zone" {
  count       = var.domain_name != "" ? 1 : 0
  name        = "dpi-${var.domain_slug != "" ? var.domain_slug : "mgmt"}"
  dns_name    = var.domain_name
  description = "DPI Center Managed Zone (${var.domain_name})"
  visibility  = "public"

  dnssec_config {
    state = "off"
  }

  lifecycle {
    prevent_destroy = true
  }

  depends_on = [google_project_service.dns_api]
}

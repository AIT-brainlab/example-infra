output "domain_name" {
  description = "Domain name for this project (empty if Cloud DNS is disabled)"
  value       = length(google_dns_managed_zone.domain_zone) > 0 ? google_dns_managed_zone.domain_zone[0].dns_name : ""
}

output "name_servers" {
  description = "Authoritative Cloud DNS nameservers (empty if Cloud DNS is disabled)"
  value       = length(google_dns_managed_zone.domain_zone) > 0 ? google_dns_managed_zone.domain_zone[0].name_servers : []
}

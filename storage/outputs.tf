output "domains" {
  description = "Custom domain → bucket it serves"
  value       = { for domain, d in local.domains : domain => d.bucket }
}

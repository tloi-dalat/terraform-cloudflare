output "access_team_domain" {
  description = "Issuer of Access tokens, TEAM_DOMAIN of the maintenance Worker"
  value       = "https://${data.cloudflare_zero_trust_organization.this.auth_domain}"
}

output "maintenance_access_aud" {
  description = "Environment → AUD of its maintenance Access app, ACCESS_AUD of the maintenance Worker"
  value       = { for env, app in cloudflare_zero_trust_access_application.maintenance : env => app.aud }
}

output "tunnel_ids" {
  description = "Tunnel name → Cloudflare tunnel ID"
  value       = { for name, t in cloudflare_zero_trust_tunnel_cloudflared.this : name => t.id }
}

output "hostnames" {
  description = "Hostname → tunnel it routes to"
  value       = { for host, h in local.hostnames : host => h.tunnel }
}

output "maintenance_access_team_domain" {
  description = "Issuer of Access tokens, TEAM_DOMAIN of the maintenance Worker"
  value       = "https://${data.cloudflare_zero_trust_organization.this.auth_domain}"
}

output "maintenance_access_aud" {
  description = "Tunnel → AUD of its maintenance Access app, ACCESS_AUD of the maintenance Worker"
  value       = { for tunnel, app in cloudflare_zero_trust_access_application.maintenance : tunnel => app.aud }
}

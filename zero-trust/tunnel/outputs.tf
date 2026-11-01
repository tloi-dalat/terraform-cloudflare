output "tunnel_ids" {
  description = "Tunnel name → Cloudflare tunnel ID"
  value       = { for name, t in cloudflare_zero_trust_tunnel_cloudflared.this : name => t.id }
}

output "hostnames" {
  description = "Hostname → tunnel it routes to"
  value       = { for host, h in local.hostnames : host => h.tunnel }
}

output "access_team_domain" {
  description = "Issuer of Access tokens"
  value       = "https://${data.cloudflare_zero_trust_organization.this.auth_domain}"
}

output "access_aud" {
  description = "Access application → AUD tag"
  value       = { for host, app in cloudflare_zero_trust_access_application.this : host => app.aud }
}

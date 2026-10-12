output "tunnel_ids" {
  description = "Tunnel name → Cloudflare tunnel ID"
  value       = { for name, t in cloudflare_zero_trust_tunnel_cloudflared.this : name => t.id }
}

output "hostnames" {
  description = "Hostname → tunnel it routes to"
  value       = { for host, h in local.hostnames : host => h.tunnel }
}

output "tunnel_ids" {
  description = "Tunnel name → Cloudflare tunnel ID"
  value       = { for name, t in cloudflare_zero_trust_tunnel_cloudflared.this : name => t.id }
}

output "hostnames" {
  description = "Hostname → tunnel it routes to"
  value       = { for host, h in local.hostnames : host => h.tunnel }
}

output "maintenance_kv_namespace_id" {
  description = "KV namespace the maintenance Worker reads each host's Access settings from"
  value       = cloudflare_workers_kv_namespace.maintenance.id
}

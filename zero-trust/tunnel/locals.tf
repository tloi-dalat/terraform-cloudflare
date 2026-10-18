locals {
  tunnels = {
    for f in fileset("${path.module}/tunnels", "*.yaml") :
    trimsuffix(f, ".yaml") => yamldecode(file("${path.module}/tunnels/${f}"))
  }

  hostname_list = flatten([
    for tunnel, cfg in local.tunnels : [
      for host in distinct([for rule in cfg.ingress : rule.hostname]) : {
        hostname = host
        tunnel   = tunnel
        zones    = [for z in var.zones : z if host == z || endswith(host, ".${z}")]
      }
    ]
  ])
  hostnames = { for h in local.hostname_list : h.hostname => h }

  access = merge([
    for tunnel, cfg in local.tunnels : {
      for host, a in try(cfg.access, {}) : host => merge(a, { tunnel = tunnel })
    }
  ]...)

  team_name = trimsuffix(data.cloudflare_zero_trust_organization.this.auth_domain, ".cloudflareaccess.com")
}

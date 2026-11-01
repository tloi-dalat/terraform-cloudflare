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

  access_whole_hosts = [for host, a in local.access : host if length(try(a.paths, [])) == 0]

  maintenance_routes = merge([
    for tunnel, cfg in local.tunnels : {
      for host in try(cfg.maintenance.hosts, []) : host => {
        tunnel = tunnel
        script = "maintenance-page-${cfg.infisical.environment}"
      }
    }
  ]...)

  maintenance_access = {
    for tunnel, cfg in local.tunnels : tunnel => cfg.maintenance
    if length(try(cfg.maintenance.emails, [])) + length(try(cfg.maintenance.github_teams, [])) > 0
  }

  maintenance_destinations = {
    for tunnel in keys(local.maintenance_access) : tunnel => [
      for h in local.hostname_list : "${h.hostname}/maintenance"
      if h.tunnel == tunnel && !contains(local.access_whole_hosts, h.hostname)
    ]
  }

  team_name = trimsuffix(data.cloudflare_zero_trust_organization.this.auth_domain, ".cloudflareaccess.com")
}

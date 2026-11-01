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

  maintenance = merge([
    for tunnel, cfg in local.tunnels : {
      for host, m in try(cfg.maintenance, {}) : host => merge(m, {
        tunnel = tunnel
        script = "maintenance-page-${cfg.infisical.environment}"
      })
    }
  ]...)

  maintenance_access = { for host, m in local.maintenance : host => m if !contains(local.access_whole_hosts, host) }

  maintenance_routes = merge([
    for host, m in local.maintenance : {
      for pattern in(
        length(try(m.paths, [])) == 0
        ? ["${host}/*"]
        : concat(flatten([for p in m.paths : ["${host}${p}", "${host}${p}/*"]]), ["${host}/maintenance", "${host}/_maintenance/*"])
      ) : pattern => { host = host, script = m.script }
    } if try(m.enabled, false) == true
  ]...)

  team_name = trimsuffix(data.cloudflare_zero_trust_organization.this.auth_domain, ".cloudflareaccess.com")
}

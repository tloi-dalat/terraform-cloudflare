locals {
  # One file per tunnel: tunnels/<tunnel-name>.yaml
  tunnels = {
    for f in fileset("${path.module}/tunnels", "*.yaml") :
    trimsuffix(f, ".yaml") => yamldecode(file("${path.module}/tunnels/${f}"))
  }

  # Every hostname gets one proxied CNAME to its tunnel, in the zone it ends with.
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
}

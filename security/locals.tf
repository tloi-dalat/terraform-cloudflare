locals {
  zones    = yamldecode(file("${path.module}/zones.yaml"))
  common   = yamldecode(file("${path.module}/common.yaml"))
  settings = yamldecode(file("${path.module}/settings.yaml"))

  apps = {
    for f in fileset("${path.module}/apps", "*.yaml") :
    trimsuffix(f, ".yaml") => yamldecode(file("${path.module}/apps/${f}"))
  }

  hosts = {
    for zone, z in local.zones : zone => [
      for app, host in z.apps : { app = app, host = host, rules = try(local.apps[app], {}) }
    ]
  }

  by_host = {
    for zone, hosts in local.hosts : zone => {
      for part in ["auth", "content", "under_attack_skip"] : part => join(" or ", [
        for h in hosts : "(http.host eq \"${h.host}\" and (${trimspace(h.rules[part])}))" if can(h.rules[part])
      ])
    }
  }

  custom_rules = {
    for zone, z in local.zones : zone => [
      for r in [
        {
          description = "Block exploit scanners"
          action      = "block"
          expression  = trimspace(local.common.scanners)
          enabled     = true
        },
        {
          description = "Challenge sign-in, sign-up, password reset and admin"
          action      = "managed_challenge"
          expression  = local.by_host[zone].auth
          enabled     = true
        },
        {
          description = "Challenge pages that create or change content"
          action      = "managed_challenge"
          expression  = local.by_host[zone].content
          enabled     = true
        },
        {
          description = "Under attack: challenge every page"
          action      = "managed_challenge"
          expression = join(" and ", compact([
            "http.host in {${join(" ", [for h in local.hosts[zone] : "\"${h.host}\""])}}",
            "not cf.client.bot",
            local.by_host[zone].under_attack_skip == "" ? "" : "not (${local.by_host[zone].under_attack_skip})",
          ]))
          enabled = try(z.under_attack, false)
        },
      ] : r if r.expression != ""
    ]
  }

  ratelimit_rules = {
    for zone, hosts in local.hosts : zone => [
      for expression in [join(" or ", [for h in hosts : "(${trimspace(h.rules.ratelimit)})" if can(h.rules.ratelimit)])] : {
        description         = "Rate limit actions sent from a page"
        expression          = expression
        period              = local.common.ratelimit.period
        mitigation_timeout  = local.common.ratelimit.mitigation_timeout
        requests_per_period = local.common.ratelimit.requests_per_period
      } if expression != ""
    ]
  }

  zone_settings = merge([
    for zone in keys(local.zones) : {
      for id, value in local.settings : "${zone}/${id}" => { zone = zone, id = id, value = value }
    }
  ]...)
}

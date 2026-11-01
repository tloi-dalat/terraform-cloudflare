resource "cloudflare_workers_route" "maintenance" {
  for_each = local.maintenance_routes

  zone_id = data.cloudflare_zone.this[one(local.hostnames[each.key].zones)].id
  pattern = "${each.key}/*"
  script  = each.value.script

  lifecycle {
    precondition {
      condition     = try(local.hostnames[each.key].tunnel, null) == each.value.tunnel
      error_message = "${each.key} is under maintenance.hosts of ${each.value.tunnel} but has no ingress rule there."
    }
  }
}

resource "cloudflare_zero_trust_access_policy" "maintenance" {
  for_each = local.maintenance_access

  account_id       = var.cloudflare_account_id
  name             = "maintenance-${each.key}"
  decision         = "allow"
  session_duration = "24h"
  include = concat(
    [for email in try(each.value.emails, []) : { email = { email = email } }],
    [for t in try(each.value.github_teams, []) : {
      github_organization = {
        name                 = split("/", t)[0]
        team                 = split("/", t)[1]
        identity_provider_id = cloudflare_zero_trust_access_identity_provider.github.id
      }
    }],
  )

  lifecycle {
    precondition {
      condition     = alltrue([for t in try(each.value.github_teams, []) : can(regex("^[^/]+/[^/]+$", t))])
      error_message = "${each.key}: maintenance github_teams entries are <org>/<team>, e.g. tloi-dalat/SRE."
    }
  }
}

resource "cloudflare_zero_trust_access_application" "maintenance" {
  for_each = local.maintenance_access

  account_id       = var.cloudflare_account_id
  name             = "maintenance-${each.key}"
  type             = "self_hosted"
  session_duration = "24h"

  destinations = [for uri in local.maintenance_destinations[each.key] : { type = "public", uri = uri }]

  policies = [{
    id         = cloudflare_zero_trust_access_policy.maintenance[each.key].id
    precedence = 1
  }]

  lifecycle {
    precondition {
      condition     = length(local.maintenance_destinations[each.key]) > 0
      error_message = "${each.key}: every hostname is already behind Access, so maintenance needs no emails or teams."
    }
  }
}

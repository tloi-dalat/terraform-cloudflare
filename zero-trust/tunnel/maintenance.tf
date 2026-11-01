resource "cloudflare_workers_route" "maintenance" {
  for_each = local.maintenance_routes

  zone_id = data.cloudflare_zone.this[one(local.hostnames[each.value.host].zones)].id
  pattern = each.key
  script  = each.value.script
}

resource "cloudflare_zero_trust_access_policy" "maintenance" {
  for_each = local.maintenance_access

  account_id       = var.cloudflare_account_id
  name             = "${each.key} maintenance"
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
      condition     = length(try(each.value.emails, [])) + length(try(each.value.github_teams, [])) > 0
      error_message = "maintenance.${each.key} needs at least one email or GitHub team."
    }
    precondition {
      condition     = alltrue([for t in try(each.value.github_teams, []) : can(regex("^[^/]+/[^/]+$", t))])
      error_message = "maintenance.${each.key}: github_teams entries are <org>/<team>, e.g. tloi-dalat/SRE."
    }
  }
}

resource "cloudflare_zero_trust_access_application" "maintenance" {
  for_each = local.maintenance_access

  account_id       = var.cloudflare_account_id
  name             = "${each.key} maintenance"
  type             = "self_hosted"
  session_duration = "24h"

  destinations = [{ type = "public", uri = "${each.key}/maintenance" }]

  policies = [{
    id         = cloudflare_zero_trust_access_policy.maintenance[each.key].id
    precedence = 1
  }]
}

resource "cloudflare_workers_kv_namespace" "maintenance" {
  account_id = var.cloudflare_account_id
  title      = "maintenance-page"
}

resource "cloudflare_workers_kv" "maintenance" {
  for_each = local.maintenance

  account_id   = var.cloudflare_account_id
  namespace_id = cloudflare_workers_kv_namespace.maintenance.id
  key_name     = each.key
  value = jsonencode({
    team_domain = "https://${data.cloudflare_zero_trust_organization.this.auth_domain}"
    aud = (
      contains(local.access_whole_hosts, each.key)
      ? cloudflare_zero_trust_access_application.this[each.key].aud
      : cloudflare_zero_trust_access_application.maintenance[each.key].aud
    )
  })

  lifecycle {
    precondition {
      condition     = try(local.hostnames[each.key].tunnel, null) == each.value.tunnel
      error_message = "maintenance.${each.key} has no ingress rule in tunnel ${each.value.tunnel}."
    }
    precondition {
      condition     = can(tobool(each.value.enabled))
      error_message = "maintenance.${each.key} needs enabled: true or false."
    }
    precondition {
      condition     = alltrue([for p in try(each.value.paths, []) : can(regex("^/[^*]+$", p))])
      error_message = "maintenance.${each.key}: paths start with /, aren't / alone and have no wildcard, e.g. /problem."
    }
    precondition {
      condition = (
        !contains(local.access_whole_hosts, each.key) ||
        length(try(each.value.emails, [])) + length(try(each.value.github_teams, [])) == 0
      )
      error_message = "maintenance.${each.key}: the host is already behind Access, so it takes no emails or github_teams."
    }
  }
}

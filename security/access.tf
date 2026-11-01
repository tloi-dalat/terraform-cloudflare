data "cloudflare_zero_trust_access_identity_providers" "this" {
  account_id = local.account_id
}

data "cloudflare_zero_trust_organization" "this" {
  account_id = local.account_id
}

resource "cloudflare_zero_trust_access_policy" "maintenance" {
  for_each = local.maintenance_access

  account_id       = local.account_id
  name             = "maintenance-${each.key}"
  decision         = "allow"
  session_duration = "24h"
  include = concat(
    [for email in try(each.value.emails, []) : { email = { email = email } }],
    [for t in try(each.value.github_teams, []) : {
      github_organization = {
        name                 = split("/", t)[0]
        team                 = split("/", t)[1]
        identity_provider_id = local.github_idp
      }
    }],
  )

  lifecycle {
    precondition {
      condition     = length(try(each.value.emails, [])) + length(try(each.value.github_teams, [])) > 0
      error_message = "maintenance.yaml ${each.key} needs at least one email or GitHub team."
    }
    precondition {
      condition     = alltrue([for t in try(each.value.github_teams, []) : can(regex("^[^/]+/[^/]+$", t))])
      error_message = "maintenance.yaml ${each.key}: github_teams entries are <org>/<team>, e.g. tloi-dalat/SRE."
    }
    precondition {
      condition     = length(try(each.value.github_teams, [])) == 0 || local.github_idp != null
      error_message = "No GitHub login method found in Access."
    }
  }
}

resource "cloudflare_zero_trust_access_application" "maintenance" {
  for_each = local.maintenance_access

  account_id       = local.account_id
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
      error_message = "maintenance.yaml ${each.key} has no zone with that environment."
    }
  }
}

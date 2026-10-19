data "cloudflare_zero_trust_organization" "this" {
  account_id = var.cloudflare_account_id
}

resource "cloudflare_zero_trust_access_identity_provider" "github" {
  account_id = var.cloudflare_account_id
  name       = "GitHub"
  type       = "github"
  config = {
    client_id     = var.github_client_id
    client_secret = var.github_client_secret
  }
}

resource "cloudflare_zero_trust_access_policy" "this" {
  for_each = local.access

  account_id       = var.cloudflare_account_id
  name             = each.key
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
}

resource "cloudflare_zero_trust_access_application" "this" {
  for_each = local.access

  account_id       = var.cloudflare_account_id
  name             = each.key
  type             = "self_hosted"
  domain           = each.key
  session_duration = "24h"

  policies = [{
    id         = cloudflare_zero_trust_access_policy.this[each.key].id
    precedence = 1
  }]

  lifecycle {
    precondition {
      condition     = contains([for rule in local.tunnels[each.value.tunnel].ingress : rule.hostname], each.key)
      error_message = "${each.key} is in access: but has no ingress rule in tunnel ${each.value.tunnel}."
    }
    precondition {
      condition     = length(try(each.value.emails, [])) + length(try(each.value.github_teams, [])) > 0
      error_message = "${each.key} needs at least one email or GitHub team."
    }
    precondition {
      condition     = alltrue([for t in try(each.value.github_teams, []) : can(regex("^[^/]+/[^/]+$", t))])
      error_message = "${each.key}: github_teams entries are <org>/<team>, e.g. tloi-dalat/sre."
    }
  }
}

data "cloudflare_zero_trust_organization" "this" {
  account_id = var.cloudflare_account_id
}

resource "cloudflare_zero_trust_access_policy" "this" {
  for_each = local.access

  account_id       = var.cloudflare_account_id
  name             = each.key
  decision         = "allow"
  session_duration = "24h"
  include          = [for email in each.value.emails : { email = { email = email } }]
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
      condition     = length(try(each.value.emails, [])) > 0
      error_message = "${each.key} needs at least one email."
    }
  }
}

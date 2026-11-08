data "cloudflare_zone" "this" {
  for_each = local.zones

  filter = {
    name = each.key
  }
}

resource "cloudflare_ruleset" "custom" {
  for_each = local.custom_rules

  zone_id = data.cloudflare_zone.this[each.key].id
  name    = "default"
  kind    = "zone"
  phase   = "http_request_firewall_custom"

  rules = [
    for r in each.value : {
      description = r.description
      action      = r.action
      expression  = r.expression
      enabled     = r.enabled
    }
  ]

  lifecycle {
    precondition {
      condition     = length(each.value) <= 5
      error_message = "${each.key}: the Free plan allows 5 custom rules per zone, got ${length(each.value)}."
    }
  }
}

resource "cloudflare_ruleset" "ratelimit" {
  for_each = local.ratelimit_rules

  zone_id = data.cloudflare_zone.this[each.key].id
  name    = "default"
  kind    = "zone"
  phase   = "http_ratelimit"

  rules = [
    for r in each.value : {
      description = r.description
      action      = "block"
      expression  = r.expression
      ratelimit = {
        characteristics     = ["ip.src", "cf.colo.id"]
        period              = r.period
        requests_per_period = r.requests_per_period
        mitigation_timeout  = r.mitigation_timeout
      }
    }
  ]

  lifecycle {
    precondition {
      condition     = length(each.value) <= 1
      error_message = "${each.key}: the Free plan allows 1 rate limiting rule per zone, got ${length(each.value)}."
    }
    precondition {
      condition     = alltrue([for r in each.value : r.period == 10 && r.mitigation_timeout == 10])
      error_message = "${each.key}: the Free plan only allows a 10s period and a 10s mitigation timeout."
    }
  }
}

resource "cloudflare_zone_setting" "this" {
  for_each = local.zone_settings

  zone_id    = data.cloudflare_zone.this[each.value.zone].id
  setting_id = each.value.id
  value      = each.value.value
}

check "known_apps" {
  assert {
    condition     = alltrue(flatten([for zone, z in local.zones : [for app in keys(z.apps) : contains(keys(local.apps), app)]]))
    error_message = "Every app in zones.yaml needs a file in apps/."
  }
}

check "expression_length" {
  assert {
    condition = alltrue(flatten([
      for zone in keys(local.zones) : [
        for r in concat(local.custom_rules[zone], local.ratelimit_rules[zone]) : length(r.expression) <= 4096
      ]
    ]))
    error_message = "A rule expression is longer than Cloudflare's 4096 characters."
  }
}

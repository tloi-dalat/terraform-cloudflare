mock_provider "cloudflare" {
  mock_data "cloudflare_zone" {
    defaults = { id = "0123456789abcdef0123456789abcdef" }
  }
}

run "every_zone_plans" {
  command = plan

  assert {
    condition     = length(cloudflare_ruleset.custom) == length(local.zones) && length(cloudflare_ruleset.ratelimit) == length(local.zones)
    error_message = "Every zone should get one custom and one rate limiting ruleset."
  }

  assert {
    condition     = alltrue([for zone, rules in local.custom_rules : length(rules) <= 5])
    error_message = "The Free plan allows 5 custom rules per zone."
  }

  assert {
    condition     = alltrue([for zone, rules in local.ratelimit_rules : length(rules) <= 1])
    error_message = "The Free plan allows 1 rate limiting rule per zone."
  }

  assert {
    condition     = local.common.ratelimit.period == 10 && local.common.ratelimit.mitigation_timeout == 10
    error_message = "The Free plan only allows a 10s period and a 10s mitigation timeout."
  }
}

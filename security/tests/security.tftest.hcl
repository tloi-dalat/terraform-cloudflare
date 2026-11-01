mock_provider "cloudflare" {
  mock_data "cloudflare_zone" {
    defaults = {
      id      = "0123456789abcdef0123456789abcdef"
      account = { id = "mock-account", name = "mock" }
    }
  }
  mock_data "cloudflare_zero_trust_access_identity_providers" {
    defaults = {
      result = [{
        id                      = "mock-github"
        name                    = "GitHub"
        type                    = "github"
        config                  = null
        read_only               = false
        saml_certificate_set    = null
        saml_certificate_set_id = null
        scim_config             = null
      }]
    }
  }
  mock_data "cloudflare_zero_trust_organization" {
    defaults = { auth_domain = "tloi.cloudflareaccess.com" }
  }
  mock_resource "cloudflare_zero_trust_access_application" {
    defaults = { aud = "mock-aud" }
  }
  mock_resource "cloudflare_zero_trust_access_policy" {
    defaults = { id = "mock-policy" }
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

run "maintenance_routes_only_listed_apps" {
  command = plan

  assert {
    condition = (
      length(cloudflare_workers_route.maintenance) == length(flatten([for zone, z in local.zones : try(z.maintenance, [])])) &&
      alltrue(flatten([for zone, z in local.zones : [for app in try(z.maintenance, []) : contains(keys(cloudflare_workers_route.maintenance), z.apps[app])]]))
    )
    error_message = "Only hosts of the apps in a zone's maintenance list should get a Worker route."
  }

  assert {
    condition     = alltrue([for host, r in local.maintenance_routes : r.script == "maintenance-page-${local.zones[r.zone].environment}"])
    error_message = "A host should route to the Worker of its zone's environment."
  }
}

run "maintenance_access_covers_every_host_of_its_environment" {
  command = plan

  assert {
    condition = alltrue(flatten([
      for zone, z in local.zones : [
        for app, host in z.apps : contains(try(local.maintenance_destinations[z.environment], ["${host}/maintenance"]), "${host}/maintenance")
      ]
    ]))
    error_message = "Every host of an environment in maintenance.yaml should have <host>/maintenance in its Access app."
  }

  assert {
    condition     = !contains(keys(local.maintenance_access), "development")
    error_message = "Development hosts are already behind Access, so they need no maintenance Access app."
  }
}

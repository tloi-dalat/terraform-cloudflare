mock_provider "cloudflare" {
  mock_data "cloudflare_zone" {
    defaults = { id = "0123456789abcdef0123456789abcdef" }
  }
  mock_data "cloudflare_zero_trust_tunnel_cloudflared_token" {
    defaults = { token = "mock-token" }
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
  mock_resource "cloudflare_zero_trust_access_identity_provider" {
    defaults = { id = "mock-github" }
  }
  mock_resource "cloudflare_zero_trust_tunnel_cloudflared" {
    defaults = { id = "00000000-0000-0000-0000-000000000000" }
  }
}

mock_provider "infisical" {}

variables {
  cloudflare_account_id = "mock-account"
  infisical_project_id  = "mock-project"
  github_client_id      = "mock-client"
  github_client_secret  = "mock-secret"
}

run "every_tunnel_file_plans" {
  command = plan

  assert {
    condition     = length(cloudflare_dns_record.this) == length(local.hostnames)
    error_message = "Every hostname should get exactly one DNS record."
  }

  assert {
    condition = alltrue([
      for name, c in cloudflare_zero_trust_tunnel_cloudflared_config.this :
      c.config.ingress[length(c.config.ingress) - 1].service == "http_status:404"
    ])
    error_message = "Every tunnel must end with the 404 catch-all."
  }
}

run "access_hostnames_require_an_access_token" {
  command = plan

  assert {
    condition = alltrue(flatten([
      for name, c in cloudflare_zero_trust_tunnel_cloudflared_config.this : [
        for rule in c.config.ingress : rule.origin_request.access.required && rule.origin_request.access.team_name == "tloi"
        if try(contains(local.access_whole_hosts, rule.hostname), false)
      ]
    ]))
    error_message = "Every hostname protected as a whole must require its Access token at the tunnel."
  }

  assert {
    condition     = length(cloudflare_zero_trust_access_application.this) == length(local.access)
    error_message = "Every access entry needs an Access application."
  }
}

run "github_teams_become_organization_rules" {
  command = plan

  assert {
    condition = alltrue(flatten([
      for host, a in local.access : [
        for t in try(a.github_teams, []) : contains(
          [for r in cloudflare_zero_trust_access_policy.this[host].include : "${r.github_organization.name}/${r.github_organization.team}" if r.github_organization != null],
          t
        )
      ]
    ]))
    error_message = "Every github_teams entry must become a github_organization include rule."
  }
}

run "path_access_protects_only_those_paths" {
  command = plan

  assert {
    condition = alltrue(flatten([
      for host, a in local.access : [
        for p in try(a.paths, []) : contains([for d in cloudflare_zero_trust_access_application.this[host].destinations : d.uri], "${host}${p}")
      ] if length(try(a.paths, [])) > 0
    ]))
    error_message = "Every path under access.<hostname>.paths needs an Access destination."
  }

  assert {
    condition = alltrue(flatten([
      for name, c in cloudflare_zero_trust_tunnel_cloudflared_config.this : [
        for rule in c.config.ingress : try(rule.origin_request.access, null) == null
        if try(length(local.access[rule.hostname].paths) > 0, false)
      ]
    ]))
    error_message = "A hostname protected only on some paths must stay reachable at the tunnel."
  }
}

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
  github_client_id      = "mock-github-client"
  github_client_secret  = "mock-github-secret"
  google_client_id      = "mock-google-client"
  google_client_secret  = "mock-google-secret"
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

run "maintenance_access_covers_every_public_hostname_of_its_tunnel" {
  command = plan

  assert {
    condition = alltrue([
      for h in local.hostname_list : contains(
        [for d in cloudflare_zero_trust_access_application.maintenance[h.tunnel].destinations : d.uri],
        "${h.hostname}/maintenance"
      ) if contains(keys(local.maintenance_access), h.tunnel) && !contains(local.access_whole_hosts, h.hostname)
    ])
    error_message = "Every hostname not behind Access needs <hostname>/maintenance in the maintenance Access app of its tunnel."
  }

  assert {
    condition     = !contains(keys(local.maintenance_access), "control-plane-development")
    error_message = "Development hosts are already behind Access, so they need no maintenance Access app."
  }
}

run "maintenance_hosts_route_to_the_worker_of_their_environment" {
  command = plan

  assert {
    condition = alltrue([
      for host, r in cloudflare_workers_route.maintenance :
      r.pattern == "${host}/*" && r.script == "maintenance-page-${local.tunnels[local.hostnames[host].tunnel].infisical.environment}"
    ])
    error_message = "A host under maintenance.hosts should route to maintenance-page-<environment>."
  }

  assert {
    condition     = length(cloudflare_workers_route.maintenance) == length(flatten([for t, cfg in local.tunnels : try(cfg.maintenance.hosts, [])]))
    error_message = "Only hosts under maintenance.hosts should get a Worker route."
  }
}

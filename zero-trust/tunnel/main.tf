resource "cloudflare_zero_trust_tunnel_cloudflared" "this" {
  for_each = local.tunnels

  account_id = var.cloudflare_account_id
  name       = each.key
  config_src = "cloudflare"
}

resource "cloudflare_zero_trust_tunnel_cloudflared_config" "this" {
  for_each = local.tunnels

  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.this[each.key].id

  config = {
    ingress = concat(
      [
        for rule in each.value.ingress : {
          hostname = rule.hostname
          path     = try(rule.path, null)
          service  = rule.service
          origin_request = (
            contains(local.access_whole_hosts, rule.hostname) || can(rule.origin_request)
            ? merge(try(rule.origin_request, {}), [
              for host in [rule.hostname] : {
                access = {
                  required  = true
                  team_name = local.team_name
                  aud_tag   = [cloudflare_zero_trust_access_application.this[host].aud]
                }
              } if contains(local.access_whole_hosts, host)
            ]...)
            : null
          )
        }
      ],
      [{ service = "http_status:404" }],
    )
  }
}

data "cloudflare_zone" "this" {
  for_each = toset(var.zones)

  filter = {
    name = each.key
  }
}

resource "cloudflare_dns_record" "this" {
  for_each = local.hostnames

  zone_id = data.cloudflare_zone.this[one(each.value.zones)].id
  name    = each.key
  type    = "CNAME"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.this[each.value.tunnel].id}.cfargotunnel.com"
  proxied = true
  ttl     = 1
  comment = "Tunnel ${each.value.tunnel}. Managed by tloi-dalat/terraform-cloudflare"

  lifecycle {
    precondition {
      condition     = length(each.value.zones) == 1
      error_message = "${each.key} is not under exactly one of var.zones (${join(", ", var.zones)})."
    }
  }
}

data "cloudflare_zero_trust_tunnel_cloudflared_token" "this" {
  for_each = local.tunnels

  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.this[each.key].id
}

resource "infisical_secret" "tunnel_token" {
  for_each = { for name, cfg in local.tunnels : name => cfg.infisical if can(cfg.infisical) }

  workspace_id = var.infisical_project_id
  env_slug     = each.value.environment
  folder_path  = each.value.path
  name         = "TUNNEL_TOKEN"
  value        = data.cloudflare_zero_trust_tunnel_cloudflared_token.this[each.key].token
}

check "unique_hostnames" {
  assert {
    condition     = length(local.hostname_list) == length(local.hostnames)
    error_message = "A hostname appears in more than one tunnel file."
  }
}

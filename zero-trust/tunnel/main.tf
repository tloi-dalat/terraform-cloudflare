# Remotely-managed tunnels: the routes live in Cloudflare, so the cluster's
# cloudflared needs nothing but the tunnel token.
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
    # Rules match top to bottom; anything unmatched gets a 404.
    ingress = concat(
      [
        for rule in each.value.ingress : {
          hostname       = rule.hostname
          path           = try(rule.path, null)
          service        = rule.service
          origin_request = try(rule.origin_request, null)
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
  ttl     = 1 # automatic (required for proxied records)
  comment = "Tunnel ${each.value.tunnel}. Managed by tloi-dalat/terraform-cloudflare"

  lifecycle {
    precondition {
      condition     = length(each.value.zones) == 1
      error_message = "${each.key} is not under exactly one of var.zones (${join(", ", var.zones)})."
    }
  }
}

# Hand the token to the cluster: Infisical → operator → Secret → cloudflared.
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

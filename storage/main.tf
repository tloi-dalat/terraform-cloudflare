data "cloudflare_zone" "this" {
  for_each = toset(var.zones)

  filter = {
    name = each.key
  }
}

resource "cloudflare_r2_bucket" "this" {
  for_each = local.buckets

  account_id = var.cloudflare_account_id
  name       = each.key
  location   = try(each.value.location, null)
}

resource "cloudflare_r2_managed_domain" "this" {
  for_each = local.buckets

  account_id  = var.cloudflare_account_id
  bucket_name = cloudflare_r2_bucket.this[each.key].name
  enabled     = false
}

resource "cloudflare_r2_custom_domain" "this" {
  for_each = local.domains

  account_id  = var.cloudflare_account_id
  bucket_name = cloudflare_r2_bucket.this[each.value.bucket].name
  domain      = each.key
  zone_id     = data.cloudflare_zone.this[each.value.zones[0]].id
  enabled     = true
  min_tls     = "1.2"

  lifecycle {
    precondition {
      condition     = length(each.value.zones) == 1
      error_message = "${each.key} is not under exactly one of var.zones (${join(", ", var.zones)})."
    }
  }
}

resource "cloudflare_r2_bucket_cors" "this" {
  for_each = local.cors

  account_id  = var.cloudflare_account_id
  bucket_name = cloudflare_r2_bucket.this[each.key].name

  rules = [
    {
      allowed = {
        methods = ["GET", "HEAD"]
        origins = each.value
      }
      max_age_seconds = 86400
    }
  ]
}

check "unique_domains" {
  assert {
    condition     = length(local.domain_list) == length(local.domains)
    error_message = "A domain appears in more than one bucket."
  }
}

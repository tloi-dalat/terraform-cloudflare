# `terraform test`: plans every tunnels/*.yaml against mocked providers, so a
# broken file fails the PR before it reaches Cloudflare. No credentials used.
mock_provider "cloudflare" {
  mock_data "cloudflare_zone" {
    defaults = { id = "0123456789abcdef0123456789abcdef" }
  }
  mock_data "cloudflare_zero_trust_tunnel_cloudflared_token" {
    defaults = { token = "mock-token" }
  }
  mock_resource "cloudflare_zero_trust_tunnel_cloudflared" {
    defaults = { id = "00000000-0000-0000-0000-000000000000" }
  }
}

mock_provider "infisical" {}

variables {
  cloudflare_account_id = "mock-account"
  infisical_project_id  = "mock-project"
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

terraform {
  required_version = ">= 1.10"

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.27"
    }
    infisical = {
      source  = "infisical/infisical"
      version = "~> 0.20"
    }
  }
}

# Credentials come from the environment (GitHub Actions secrets, see README):
#   cloudflare: CLOUDFLARE_API_TOKEN
#   infisical:  INFISICAL_AUTH_METHOD=universal,
#               INFISICAL_UNIVERSAL_AUTH_CLIENT_ID, INFISICAL_UNIVERSAL_AUTH_CLIENT_SECRET
provider "cloudflare" {}
provider "infisical" {}

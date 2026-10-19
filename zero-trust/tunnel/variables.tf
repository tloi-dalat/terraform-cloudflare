variable "cloudflare_account_id" {
  description = "Cloudflare account ID (TF_VAR_cloudflare_account_id)"
  type        = string
}

variable "infisical_project_id" {
  description = "Infisical project the tunnel tokens are written to (TF_VAR_infisical_project_id)"
  type        = string
}

variable "zones" {
  description = "Cloudflare zones (domains) that tunnel hostnames may live under"
  type        = list(string)
  default     = ["tloi.shop", "tloi.vn"]
}

variable "github_client_id" {
  description = "GitHub OAuth App client ID for the Access login method (TF_VAR_github_client_id)"
  type        = string
}

variable "github_client_secret" {
  description = "GitHub OAuth App client secret (TF_VAR_github_client_secret)"
  type        = string
  sensitive   = true
}

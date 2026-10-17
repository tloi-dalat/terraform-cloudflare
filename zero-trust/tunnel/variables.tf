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

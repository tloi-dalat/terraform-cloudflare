variable "cloudflare_account_id" {
  description = "Cloudflare account ID (TF_VAR_cloudflare_account_id)"
  type        = string
}

variable "zones" {
  description = "Cloudflare zones (domains) that bucket domains may live under"
  type        = list(string)
  default     = ["tloi.shop", "tloi.vn"]
}

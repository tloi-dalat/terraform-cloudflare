terraform {
  # State lives in Cloudflare R2 through its S3 API. The endpoint and keys come
  # from the environment: AWS_ENDPOINT_URL_S3 (https://<account-id>.r2.cloudflarestorage.com),
  # AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY.
  # No state lock (R2 locking is best-effort); CI runs one apply at a time.
  backend "s3" {
    bucket = "tloi-terraform-state"
    key    = "terraform-cloudflare/zero-trust/tunnel.tfstate"
    region = "auto"

    use_path_style              = true
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true
  }
}

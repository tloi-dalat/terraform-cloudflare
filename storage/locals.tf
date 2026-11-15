locals {
  buckets = yamldecode(file("${path.module}/buckets.yaml"))

  domain_list = flatten([
    for bucket, b in local.buckets : [
      for domain in try(b.domains, []) : {
        domain = domain
        bucket = bucket
        zones  = [for z in var.zones : z if domain == z || endswith(domain, ".${z}")]
      }
    ]
  ])
  domains = { for d in local.domain_list : d.domain => d }

  cors = { for bucket, b in local.buckets : bucket => b.cors_origins if length(try(b.cors_origins, [])) > 0 }
}

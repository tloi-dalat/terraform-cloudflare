# terraform-cloudflare

Cloudflare for every TLOI cluster, as code: tunnels, their routes, and the DNS
records that point at them.

A pull request gets a comment with the plan (updated on every push); merging to `main` applies it.

```
zero-trust/tunnel/
  tunnels/<tunnel-name>.yaml   ← one file per tunnel: routes (+ where its token goes)
  main.tf                      tunnel, routes, one DNS CNAME per hostname, token → Infisical
  tests/                       `terraform test` with mocked providers (runs on every PR)
```

## Add or change a hostname

Edit the tunnel's file, e.g. `zero-trust/tunnel/tunnels/control-plane-development.yaml`:

```yaml
ingress:
  - hostname: quiz.tloi.shop
    service: http://quiz-web.quiz.svc.cluster.local:8000
```

Open a PR, read the plan, merge. The DNS record is created and the route goes
live without restarting anything in the cluster. A hostname must be under one
of the zones in `variables.tf` (`tloi.shop`); add new domains there.

Rule fields: `hostname`, `service`, optional `path` (a regex) and
`origin_request` (Cloudflare's origin settings, e.g. `no_tls_verify: true`).
Rules match top to bottom; unmatched requests get a 404.

## Add a tunnel (e.g. production)

Add `tunnels/control-plane-production.yaml` with an `infisical:` block naming
the environment and folder for its token. Terraform creates the tunnel and puts
`TUNNEL_TOKEN` into that Infisical folder; the cluster's cloudflared reads it
from there (control-plane `clusters/<env>/cloudflared/tunnel`).

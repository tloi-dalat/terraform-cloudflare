# terraform-cloudflare

Cloudflare for every TLOI cluster, as code: tunnels, their routes, and the DNS
records that point at them.

A pull request gets a comment with the plan (updated on every push); merging to `main` applies it.
Nobody runs `cloudflared tunnel …` by hand.

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

## One-time setup

1. **R2 bucket for state:** Cloudflare dashboard → R2 → create bucket
   `tloi-terraform-state`. Then R2 → Manage API tokens → create an
   *Object Read & Write* token for that bucket; note its Access Key ID and
   Secret Access Key.
2. **Cloudflare API token:** My Profile → API Tokens → Create custom token with
   - Account → Cloudflare Tunnel → Edit
   - Zone → DNS → Edit, and Zone → Zone → Read, for zone `tloi.shop`
3. **Infisical:** create folder `/cloudflared` in environment `development`.
   Create a machine identity `terraform-cloudflare` (Universal Auth, org role
   No Access) and add it to the project with a role that can write secrets.
4. **GitHub → Settings → Secrets and variables → Actions:**

   | Kind | Name | Value |
   |---|---|---|
   | secret | `CLOUDFLARE_API_TOKEN` | token from step 2 |
   | secret | `R2_ACCESS_KEY_ID` / `R2_SECRET_ACCESS_KEY` | keys from step 1 |
   | secret | `INFISICAL_CLIENT_ID` / `INFISICAL_CLIENT_SECRET` | identity from step 3 |
   | variable | `CLOUDFLARE_ACCOUNT_ID` | dashboard → any zone → Overview → Account ID |
   | variable | `INFISICAL_PROJECT_ID` | Infisical → project → Settings → Project ID |

5. Commit `.terraform.lock.hcl` after the first init, for every platform you run on:
   `terraform providers lock -platform=linux_amd64 -platform=darwin_arm64`

## Running locally

Export the same variables as the workflow (`CLOUDFLARE_API_TOKEN`,
`TF_VAR_cloudflare_account_id`, `AWS_ENDPOINT_URL_S3`, `AWS_ACCESS_KEY_ID`,
`AWS_SECRET_ACCESS_KEY`, `TF_VAR_infisical_project_id`, `INFISICAL_*`), then
`terraform init && terraform plan -lock=false` in the workspace. Don't apply
locally while CI might: the state has no lock.

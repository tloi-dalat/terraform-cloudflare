# Tunnels

One file per tunnel in `zero-trust/tunnel/tunnels/`; the file name is the tunnel name. Each cluster runs one
tunnel (`control-plane-development`, `control-plane-production`), and its cloudflared needs only the token.

```yaml
infisical:
  environment: production
  path: /cloudflared

ingress:
  - hostname: oj.tloi.vn
    path: ^/event/
    service: http://online-judge-wsevent.online-judge.svc.cluster.local:15100
  - hostname: oj.tloi.vn
    service: http://online-judge-site.online-judge.svc.cluster.local:8000
```

- `infisical`: where Terraform writes the tunnel's `TUNNEL_TOKEN`. control-plane's
  `clusters/<env>/cloudflared/tunnel` reads it from there.
- Rules: `hostname`, `service`, optional `path` (a regex) and `origin_request` (e.g. `no_tls_verify: true` for a
  self-signed origin). They match top to bottom; unmatched requests get a 404.
- Services are in-cluster: `http://<service>.<namespace>.svc.cluster.local:<port>`.
- Every hostname gets one proxied CNAME to its tunnel. It must be under exactly one zone in `variables.tf`
  (`tloi.shop`, `tloi.vn`), and appear in only one tunnel file.

## Access

```yaml
access:
  sqllab.tloi.vn:
    emails: [someone@example.com]
```

A hostname under `access:` gets a Cloudflare Access application that lets in only those emails (login by one-time
PIN, or any login method enabled in Zero Trust → Settings → Authentication). Its ingress rules also get
`origin_request.access`, so the tunnel drops requests without a valid Access token for that application. The
hostname needs at least one ingress rule in the same file.

## Add a hostname

Add its rules, open a PR, read the plan comment, merge. The route goes live without restarting anything.

If the hostname already has a DNS record (for example, pointing at an old server), the apply fails on it. Delete
that record in Cloudflare right before merging.

## Add a tunnel

Add `tunnels/<name>.yaml` with an `infisical:` block. Terraform creates the tunnel, its DNS records, and the token
in Infisical.

## New domain

Add it to `zones` in `variables.tf`, and give the Cloudflare API token DNS edit on it.

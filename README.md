# terraform-cloudflare

Cloudflare for every TLOI cluster, as code: tunnels, their routes, the DNS records pointing at them, and each
tunnel's token in Infisical. Atlantis runs it: comment `atlantis plan` on a PR, get an `sre` approval, comment
`atlantis apply`; Atlantis applies and merges.

- `docs/tunnels.md`: tunnel files, adding a hostname or a tunnel

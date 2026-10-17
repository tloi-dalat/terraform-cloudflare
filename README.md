# terraform-cloudflare

Cloudflare for every TLOI cluster, as code: tunnels, their routes, the DNS records pointing at them, and each
tunnel's token in Infisical. A pull request gets the plan as a comment; merging to `main` applies it.

- `docs/tunnels.md`: tunnel files, adding a hostname or a tunnel
- `docs/setup.md`: secrets and how CI runs

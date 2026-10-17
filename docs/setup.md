# One-time setup

A pull request gets a plan comment (updated on every push); merging to `main` applies it. One apply runs at a
time: the R2 state has no lock, so the workflow's concurrency group is the lock.

Repository secrets and variables:

| Name | Kind | What |
|---|---|---|
| `CLOUDFLARE_API_TOKEN` | secret | Account: Cloudflare Tunnel edit; Zone: DNS edit on every zone in `variables.tf` |
| `CLOUDFLARE_ACCOUNT_ID` | variable | Also builds the R2 endpoint |
| `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY` | secret | R2 API token for bucket `tloi-terraform-state` |
| `INFISICAL_PROJECT_ID` | variable | The TLOI project |
| `INFISICAL_CLIENT_ID`, `INFISICAL_CLIENT_SECRET` | secret | A machine identity that can write `/cloudflared` in each environment |

`tests/` runs `tofu test` against mocked providers on every PR, so a broken tunnel file fails before it reaches
Cloudflare.

# Security rules

`security/` manages the WAF rules and security settings of every zone in `security/zones.yaml`, sized for the Free
plan (5 custom rules, 1 rate limiting rule with a 10s window that can only match the path, no regex). However many
apps a zone has, it always uses the same 4 custom rules and 1 rate limiting rule: each app adds its paths to them.

```yaml
# zones.yaml
tloi.vn:
  under_attack: false
  apps:
    online-judge: oj.tloi.vn
```

- `apps/<app>.yaml`: an app's paths, by part. Every part is optional:
  - `auth`: sign-in, sign-up, password reset, admin pages;
  - `content`: pages with a form that creates or changes content;
  - `under_attack_skip`: paths left alone in "Under attack" (WebSockets, APIs, static files);
  - `ratelimit`: requests a page sends by script (votes, uploads). The rate limiting rule can't match the host, so
    keep these paths specific to the app.
- `common.yaml`: the scanner paths blocked on every host, and the rate limit (20 requests per 10s per IP).
- `settings.yaml`: zone settings for every zone. `challenge_ttl: 86400` keeps a passed challenge for a day, so a
  form opened behind a challenge can still be posted hours later.

| Rule | What | Why |
|---|---|---|
| Block exploit scanners | `*.php`, `/wp-*`, `/.env`, `/.git`, … on every host | none of our apps serve them |
| Challenge sign-in, sign-up, password reset and admin | each app's `auth`, every method | stops password guessing, bot sign-ups and reset spam |
| Challenge pages that create or change content | each app's `content`, every method | bots can't post; people pass once, then the form posts without another challenge |
| Under attack (`under_attack: true`) | every page of the zone's apps except `under_attack_skip` and verified bots | turn on during an attack |
| Rate limit actions sent from a page | each app's `ratelimit` | a challenge page would break these |

Challenges go on pages a person opens, never on requests a page sends by script: those can't show a challenge.
The Cloudflare Free Managed Ruleset and the automatic DDoS protection stay on by default and aren't managed here.
Bot Fight Mode stays off: on the Free plan no rule can skip it, and it would block the webhooks and API clients.

## Add an app

Add `apps/<app>.yaml` with its parts, then list it with its host under each zone in `zones.yaml`.

## Turn on "Under attack"

Set `under_attack: true` on the zone, plan and apply. Turn it off again the same way.

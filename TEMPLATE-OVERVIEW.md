# Deploy and Host Bifrost on Railway

Bifrost is an OpenAI-compatible AI gateway written in Go: one address in front of every provider, with virtual keys, budgets and rate limits, and overhead measured in microseconds rather than milliseconds.

This template deploys it with the three things the upstream image leaves to you: admin authentication, a virtual key requirement on the inference routes, and Postgres for configuration and logs.

## About Hosting Bifrost

The reason to choose Bifrost over the Python gateways is throughput — a Go process does not have a global interpreter lock to queue behind, and it holds its latency as request volume rises.

The reason to be careful deploying it is that its defaults assume a private network. Run the image as it ships on a public domain and three things are true at once: the dashboard and admin API accept anyone, so your provider keys and request logs are readable by whoever finds the URL; the `/v1` endpoint accepts anyone, so your provider credit is spendable by them too; and the configuration sits in a file on the container's disk, so a redeploy loses the providers you set up.

Every one of those is a setting, not a limitation. This template sets them.

## Common Use Cases

- **A shared gateway for a team.** Issue a virtual key per person or per service, with its own allowed models, rate limit and budget, and revoke it without touching a provider key.
- **High-throughput serving.** Where a Python proxy starts queueing, a Go gateway keeps its latency flat — the reason to pick this one over the alternatives.
- **Provider failover.** Route a model group across providers so one outage is not yours.

## Dependencies for Bifrost Hosting

### Deployment Dependencies

- [Bifrost](https://github.com/maximhq/bifrost) — the gateway, pinned to `maximhq/bifrost:v1.6.6`
- Postgres 16 or above, UTF8 — configuration store and log store
- [Template source](https://github.com/ak40u/bifrost-railway-starter)

### Implementation Details

- **Admin authentication is on**, with credentials generated at deploy time. `governance.auth_config.is_enabled` is the switch; without it the dashboard is public.
- **The inference routes require a virtual key** via `client.enforce_auth_on_inference`. Worth knowing: the older `disable_auth_on_inference` under `auth_config` is deprecated and silently ignored, so a config that only sets that one leaves `/v1` open while looking closed.
- **Both stores are in Postgres** — configuration and request logs. A redeploy finds the same providers, keys and history; the volume on `/app/data` holds only the rendered config file, because the upstream image declares that mount point.
- **`config.json` is written at start, not baked in.** Secrets arrive as `env.` references, so no password ends up in an image layer, and upgrading the template actually replaces the file rather than leaving a stale copy on a volume.
- **The container refuses to start** without a database host or an admin password, rather than coming up in a state that only looks configured.
- **The image is pinned to an exact release.** Bifrost ships often; a moving tag means a different gateway after every restart.

The repository carries `scripts/verify-gateway.sh`, which checks that the admin API refuses anonymous callers, that a provider survives the round trip through Postgres, that inference is refused without a virtual key, and that a virtual key gets through. It makes no call to any provider and deletes what it creates. This template was published only after that script passed against a deployment created from the template itself.

## Why Deploy Bifrost on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying Bifrost on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.

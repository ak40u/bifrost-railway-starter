# Bifrost gateway starter for Railway

An OpenAI-compatible gateway in front of every provider you use, written in Go —
and closed by default, which is the part that takes the work.

## Why this exists

Bifrost is fast: a Go gateway with microsecond-scale overhead per request, where
the Python alternatives start queueing under sustained load. What it is not, out
of the box, is safe to put on a public address.

Deploy the upstream image as it ships and you get:

- an **admin API and dashboard with no authentication** — anyone who finds the
  URL can add providers, read your request logs, and see your configuration;
- an **inference endpoint anyone can use** — with your provider keys and your
  money;
- **configuration on the container's disk**, which on most platforms means it is
  gone on the next deploy.

This template fixes all three. Admin credentials are generated and enforced,
`/v1` requires a virtual key, and both the configuration store and the log store
are in Postgres — so there is no volume, the container keeps nothing, and you
can run as many replicas as you like.

## After deploying

1. Open the dashboard and sign in with the generated `BIFROST_ADMIN_USERNAME`
   and `BIFROST_ADMIN_PASSWORD`.
2. **Providers** → add a provider and paste your API key.
3. **Virtual keys** → create one. Inference requires it: without a virtual key
   every call to `/v1` is refused.

Then point your client at `https://<your-domain>/v1` and send the virtual key in
`x-bf-vk` (or `Authorization: Bearer`, `x-api-key`, `x-goog-api-key` — Bifrost
accepts the header your SDK already sends).

## Prove it works

```bash
scripts/verify-gateway.sh https://your-gateway.up.railway.app admin 'the-password'
```

It checks that the admin API refuses anonymous callers and accepts yours, that a
provider written through the API comes back out of Postgres, that inference is
refused without a virtual key, and that a virtual key gets a request through
routing. It cleans up after itself, and it makes no call to any provider.

## Configuration

| Variable | Required | Purpose |
|----------|----------|---------|
| `BIFROST_ADMIN_USERNAME` / `BIFROST_ADMIN_PASSWORD` | yes | Dashboard and admin API credentials. The container refuses to start without the password |
| `PGHOST` / `PGPORT` / `PGUSER` / `PGPASSWORD` / `PGDATABASE` | yes | Postgres for the config and log stores. Version 16 or above, UTF8 |
| `APP_PORT` / `APP_HOST` | no | 8080 and 0.0.0.0; the defaults the container is built with |
| `LOG_STYLE` | no | `pretty` or `json` |

Provider API keys are not variables — add them in the dashboard, where they are
stored in Postgres.

## How the configuration is applied

`config.json` is copied into `APP_DIR` at start rather than baked into the image,
so upgrading this template actually replaces it, and no password is ever written
into an image layer. Values come in as `env.` references, which is Bifrost's own
mechanism for keeping secrets out of the file.

Two settings carry the weight:

- `governance.auth_config.is_enabled` — turns on admin authentication.
- `client.enforce_auth_on_inference` — requires a virtual key on `/v1`. Note that
  the older `disable_auth_on_inference` is deprecated and silently ignored; if
  you have it in a config somewhere, it is doing nothing.

## Bifrost or LiteLLM?

Bifrost is faster and its governance model is stronger. LiteLLM knows more
providers and is what most guides assume. Both are published as templates; pick
by whether you care more about throughput or about breadth.

## License

The template configuration is MIT. Bifrost itself is Apache-2.0 with an
enterprise tier — see the upstream project.

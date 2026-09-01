# Security

TorrenCloud is built for a single owner running it on their own server. That assumption
shapes everything below — read it before putting one on the public internet.

## Claim a new install immediately

A fresh instance is unclaimed, and the setup endpoint is anonymous by necessity: there is
no account to authenticate against yet. **Whoever completes the wizard first owns the
instance.**

Once claimed, the endpoint returns 409 to every later attempt, and the check runs inside
the same transaction that records the claim.

So: do not start a public instance and walk away. Either complete the wizard straight
away, or start it bound to localhost and open the firewall afterwards.

## Where secrets live

`/data/postgres/secrets.env`, on the `torrencloud-pgdata` volume, mode 600:

| Value | Used for |
|-------|----------|
| `GENERATED_POSTGRES_PASSWORD` | The database user |
| `GENERATED_JWT_SECRET` | Signing API tokens |
| `GENERATED_NEXTAUTH_SECRET` | Encrypting sessions |
| `GENERATED_GRAFANA_PASSWORD` | Grafana admin |

Read them with `docker exec torrencloud cat /data/postgres/secrets.env`.

Anyone with the volume, or root on the host, has all of these. That is the same trust
boundary as the database itself.

Your cloud credentials — Google OAuth client secrets, S3 keys, refresh tokens — are stored
in the database **unencrypted**. They are protected by the volume, not by cryptography.
Treat a database dump as equivalent to handing over access to the connected storage.

## Your account

- One account per instance. No registration.
- Password stored hashed — PBKDF2, per-password salt, versioned format, constant-time
  verification. Minimum 12 characters.
- **No password reset.** Nothing on the server can send email. A lost password means
  recreating the instance.
- Login tokens are valid for 7 days and cannot be revoked individually. Rotating
  `JWT_SECRET` invalidates all of them at once.

There is no rate limiting on the login endpoint, only a fixed delay on failure. A long
password is doing real work here.

## What each port exposes

| Port | Authentication |
|------|----------------|
| 47100 — App | Login required |
| 47200 — API | Bearer token required, except `/api/health`, `/api/setup/*` and the OAuth callback |
| 47200 — `/hangfire` | **None** |
| 47500 — Grafana | Grafana's own login |
| 47600 — Prometheus | **None** |

Two of those need attention.

### The Hangfire dashboard is unauthenticated

`/hangfire` on port 47200 is reachable by anyone who can reach the port. It shows job
history, arguments and server state, and it can delete and requeue jobs.

There is no role system to gate it with yet. Until there is:

- Do not expose 47200 publicly. The browser reaches the API through the frontend's
  same-origin proxy on 47100, so a normal install does not need 47200 open at all.
- If you do expose it, block `/hangfire` at your reverse proxy, or put HTTP basic auth in
  front of it.

### Prometheus is unauthenticated

Port 47600 has no login. It exposes metrics, not credentials, but there is no reason to
publish it. Drop `-p 47600:47600` unless you are scraping it from elsewhere.

## CORS

The API allows any origin. It is meaningless as a control here because every browser
request is same-origin through the frontend proxy, but it does mean an exposed 47200 will
answer cross-origin requests. Another reason to keep it closed.

## Recommended setup for a public instance

1. Publish only 47100. Drop 47200, 47500 and 47600 from your `docker run`.
2. Put a reverse proxy in front with TLS — see
   [Installation](Installation#behind-a-reverse-proxy).
3. Complete the setup wizard before opening the firewall.
4. Use a long, unique password.
5. Back up `/data/postgres/secrets.env` somewhere private — see [Updating](Updating).

## Torrent traffic

The torrent client connects out to peers and trackers directly, from the server's IP. It
does not route through a VPN, and there is no proxy setting. If that matters where you
are, run the container on a host that is already behind one.

## Reporting a problem

Open an issue on [TorrenClou/deploy](https://github.com/TorrenClou/deploy/issues). For
anything you would rather not post publicly, say so in the issue without the details and a
maintainer will follow up.

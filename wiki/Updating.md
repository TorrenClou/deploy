# Updating

## The short version

```bash
curl -fsSL https://raw.githubusercontent.com/TorrenClou/deploy/main/install.sh | bash
```

The installer replaces the container and leaves the volumes alone, so your database,
downloads and secrets survive.

Or by hand:

```bash
docker pull ghcr.io/torrenclou/torrentclou:latest
docker rm -f torrencloud
# then the same docker run you used originally
```

Database migrations run automatically at start. Watch `docker logs -f torrencloud` for
`Database migrations applied successfully`.

## Before a big upgrade: back up

The one thing you cannot recreate is the `torrencloud-pgdata` volume. It holds your
account, your storage credentials, your job history — **and the generated secrets**.

```bash
docker exec torrencloud pg_dump -U torrenclo_user torrenclo > torrenclou-backup.sql
docker exec torrencloud cat /data/postgres/secrets.env > torrenclou-secrets.env
```

PowerShell:

```powershell
docker exec torrencloud pg_dump -U torrenclo_user torrenclo | Out-File -Encoding utf8 torrenclou-backup.sql
docker exec torrencloud cat /data/postgres/secrets.env | Out-File -Encoding utf8 torrenclou-secrets.env
```

Keep `torrenclou-secrets.env` somewhere safe and private — it contains the database
password and the token signing keys. Restoring the database without it leaves everyone
logged out and the database password mismatched.

## Restoring

```bash
docker exec -i torrencloud psql -U torrenclo_user -d torrenclo < torrenclou-backup.sql
docker restart torrencloud
```

If the container was recreated from scratch, put the secrets back before starting it, or
pass the old `JWT_SECRET`, `NEXTAUTH_SECRET` and `POSTGRES_PASSWORD` as environment
variables.

## Rolling back

Images are tagged `YYYY.MM.DD-<backend-sha>-<frontend-sha>` as well as `latest`:

```bash
docker rm -f torrencloud
docker run -d ... ghcr.io/torrenclou/torrentclou:2026.01.15-a1b2c3d-e4f5g6h
```

The list of tags is on the
[package page](https://github.com/orgs/TorrenClou/packages).

**Migrations do not roll back.** If the version you are leaving added a database change,
the older image may not start against the newer schema. Restore the pre-upgrade dump as
well, which is the reason to take one.

## Pinning a version

Run a specific tag instead of `latest` and it stays put until you change it. Sensible if
you would rather choose when to take an update.

## What version am I on?

```bash
docker inspect torrencloud --format '{{.Config.Image}}'
docker inspect ghcr.io/torrenclou/torrentclou:latest --format '{{index .Config.Labels "org.opencontainers.image.revision"}}'
```

## Release cadence

The image rebuilds whenever the backend or frontend merges to `main`, so `latest` moves
with development. There is no fixed schedule. Pin a tag if you want a slower pace.

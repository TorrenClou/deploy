# Troubleshooting

Start here:

```bash
docker logs -f torrencloud
```

Nine processes share that log, each line prefixed with which one it came from.

## Health endpoints

```bash
curl http://localhost:47200/api/health/ready
curl http://localhost:47200/api/setup/status
```

The second one tells you whether the instance thinks it has been set up.

## The container will not start

```bash
docker logs torrencloud | head -50
```

**`address already in use`** — something else holds 47100 or 47200. Find it with
`sudo lsof -i :47100`, or map different host ports (`-p 8080:47100`).

**Permission errors on `/data`** — usually a bind-mounted directory the container cannot
write. `chmod 777` the downloads path, or use the named volume.

**It restarts in a loop** — `docker logs` shows the last failure before each restart. A
`set -e` failure in the entrypoint aborts before supervisord starts, so look at the very
first lines.

## The setup wizard will not appear

Check the status:

```bash
curl http://localhost:47200/api/setup/status
```

`{"needsSetup":false}` on an instance you have never configured means one of two things:

- **`ADMIN_EMAIL` and `ADMIN_PASSWORD` are set.** That deliberately disables the wizard —
  log in with those instead. Remove them if you want the wizard.
- **Someone already claimed it.** If it was exposed before you got to it, treat it as
  compromised: destroy the volumes and start again. See
  [Security](Security#claim-a-new-install-immediately).

## The wizard appears but I already have an account

`{"needsSetup":true}` when you expect otherwise means the database is empty — most often a
new or renamed volume. Check what is mounted:

```bash
docker inspect torrencloud --format '{{json .Mounts}}'
```

## I cannot log in

There is no password reset. If the password is genuinely lost, the account cannot be
recovered — that is a design consequence of having no mail server, not a bug.

As a last resort you can start the container with `ADMIN_EMAIL` and `ADMIN_PASSWORD` set to
the *existing* account's email and a new password; the legacy path adopts that user row and
rehashes it, preserving your jobs and storage profiles.

## Google Drive will not connect

**`redirect_uri_mismatch`** — the redirect URI in the Google console does not match what
the app sends. It must match exactly, including scheme and port:

```
http://your-address:47100/proxy/api/storage/gdrive/callback
```

The app shows the exact string on the credentials form. Copy it from there rather than
typing it. If you moved the app to a new address, add the new URI in the console.

**The popup opens and closes with nothing happening** — usually a blocked popup, or the
consent screen refusing because your Google account is not listed under **Test users**.

**It connects, then goes unhealthy** — the refresh token was revoked. That happens if you
remove the app's access in your Google account, or if an unverified app's token expires.
Use **Reconnect** on the storage profile.

**The callback lands on the wrong address** behind a proxy — your proxy is not sending
`X-Forwarded-Host`. Either fix the proxy or set `PUBLIC_FRONTEND_URL`. See
[Installation](Installation#behind-a-reverse-proxy).

## S3 shows as unhealthy

The health check lists objects in the bucket, so:

- The bucket must exist
- The key needs read access, not just write
- The endpoint must be the account-specific one for R2 and Backblaze

## Jobs sit in QUEUED

Usually not a fault. A download holds a worker for its entire transfer, so with concurrent
transfers set to 10 the eleventh waits. The job detail page says which case you are in: if
every slot is busy it tells you so, and starting it manually would only put it back in the
same queue.

If it says a worker is free and the job still has not started, it was missed when queued.
**Force Start** hands it straight to a worker.

To raise the ceiling: **Settings → Transfers → Concurrent transfers**, then restart the
container.

## A job keeps retrying its upload

Check the error on the job detail page.

- **Quota** — the drive is full. Connect another, or free space.
- **Reauth needed** — reconnect the storage profile.
- **A specific file failing repeatedly** — the job page names it.

If rerouting is on, the job should move to another healthy drive after the failure
threshold. If you have only one drive there is nowhere to move to.

## Disk filling up

**Settings → Local Storage** shows what the downloads volume holds and what can be
reclaimed. **Purge** deletes the directories of completed and cancelled jobs only.

If "Delete downloads after upload" is off, that is expected — nothing is cleaned up
automatically.

Directories counted as **orphaned** have no matching job. They are never deleted
automatically; remove them by hand if you are sure:

```bash
docker exec torrencloud ls -la /data/downloads
```

## Getting into the database

```bash
docker exec -it torrencloud psql -U torrenclo_user -d torrenclo
```

Tables are in the `dev` schema, so quote them: `SELECT * FROM dev."UserJobs";`

## Nothing here helped

Open an issue on [TorrenClou/deploy](https://github.com/TorrenClou/deploy/issues) with:

- `docker logs torrencloud | tail -100`
- Your `docker run` command, with secrets removed
- The image tag: `docker inspect torrencloud --format '{{.Config.Image}}'`

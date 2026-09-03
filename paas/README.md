# PaaS blueprints

Deployment instructions live at
**[tc.gitnasr.com/docs/paas](https://tc.gitnasr.com/docs/paas)** — one page per
platform. This file describes what is in this directory and why the files look
the way they do.

| Directory | File the platform reads |
|-----------|-------------------------|
| `dokploy/` | `docker-compose.yml` |
| `coolify/` | `docker-compose.yml` |
| `render/` | `render.yaml` |
| `railway/` | `railway.json`, plus a README covering what it does not do |

## Why these all run the all-in-one image

Worth recording here, because the obvious alternative looks better on paper and
someone will eventually try it.

A service per component with managed PostgreSQL and Redis does not work.
**The three workers share a filesystem**: the torrent worker downloads into
`/data/downloads` and the Google Drive and S3 workers read those files back to
upload them. On Render and Railway a disk attaches to exactly one service, so
split across services the upload workers cannot see what the torrent worker
produced. Downloads succeed and every upload fails, with an error that reads
like bad storage credentials rather than a topology mistake.

Neither platform offers a shared filesystem to work around it.

One container with one volume at `/data` avoids the problem and persists the
database, Redis and the first-boot secrets at the same time. The usual objection
to an all-in-one image on a PaaS — ephemeral filesystem, database gone on
redeploy — stops applying once there is a disk. The cost is a larger instance.

`../compose/docker-compose.split.yml` keeps the split topology for self-hosting,
where a Docker named volume **can** be shared between containers.

## Volume names

`torrencloud-*`, matching what the installer has always created. A volume name
is a user-owned identifier: renaming one migrates nothing, it silently starts an
empty database while the user believes their downloads are gone.

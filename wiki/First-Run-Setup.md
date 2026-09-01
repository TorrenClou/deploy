# First-run setup

The first time you open the app it shows a three-step wizard. Only the first step is
required.

## 1. Create your account

Name, email, password. This becomes the admin account for the instance.

Two things worth knowing:

- **It is the only account.** There is no registration and no second user.
- **There is no password reset.** Nothing on the server can email you, so a lost password
  means recreating the instance. Put it in a password manager.

The password is stored hashed (PBKDF2, per-password salt). Minimum 12 characters.

Once this step completes the instance is claimed, and the setup endpoint refuses every
later attempt. That matters: until you complete it, anyone who can reach the app can claim
it. Do not leave a fresh install exposed to the internet unclaimed.

## 2. Connect your storage

Skippable — you can do it later under **Storage**.

Both providers use your own credentials. Nothing is proxied through a third-party service,
and the credentials are stored on your server.

### Google Drive

Google requires an OAuth app, and it has to be yours. It takes about five minutes.

1. Open the [Google Cloud Console](https://console.cloud.google.com/) and create a project,
   or pick an existing one.
2. Enable the **Google Drive API** for it.
3. Configure the OAuth consent screen. **External** is fine. Add your own Google account
   under **Test users** — otherwise Google blocks the sign-in until the app is verified,
   which you do not need for personal use.
4. Create credentials → **OAuth client ID** → **Web application**.
5. For **Authorized redirect URIs**, paste the URI the app shows you on that screen. It
   looks like:

   ```
   http://your-address:47100/proxy/api/storage/gdrive/callback
   ```

   It must match exactly, including the port and the scheme. This is the single most
   common thing to get wrong.
6. Copy the client ID and client secret into the form and save.
7. Click connect, approve in the popup, and the drive appears in your list.

If you later move the app to a different address, add the new redirect URI in the Google
console — the old one keeps working, so you can add rather than replace.

### S3-compatible

Endpoint, access key, secret key, bucket, region. Works with AWS, Backblaze B2, Cloudflare
R2, DigitalOcean Spaces, Wasabi and MinIO; the form has presets for the common ones.

For Cloudflare R2 pick the R2 preset and paste your account-specific endpoint, since R2
gives each account its own hostname.

The bucket must already exist. The credentials need read and write on it — the app lists
objects to check the connection is healthy, so a write-only key reports as unhealthy.

## 3. Preferences

Three settings, all changeable later in **Settings**:

- **Delete downloads after upload** — on by default. Reclaims disk as soon as every file
  has reached your storage.
- **Reroute failed uploads** — on by default. If a drive stops accepting uploads, the job
  moves to another healthy one rather than failing.
- **Concurrent transfers** — how many torrents run at once. A download holds a worker for
  its entire transfer, so this is a hard ceiling, not a guideline. Changing it needs a
  restart.

## Afterwards

Upload a `.torrent` under **Torrents**, pick the files you want, choose a destination, and
start it. Progress is on the **Jobs** page.

## Upgrading an older install

If your instance predates the wizard and you have `ADMIN_EMAIL` and `ADMIN_PASSWORD` set,
nothing changes: those credentials still work, and the wizard stays off. The first time you
log in with them the password is converted to a stored hash, after which you can remove
both variables and change the password under **Settings → Account**.

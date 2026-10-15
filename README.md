# popcorn_flutter
Watch movies and TV series on the go!

## Admin Web Push Notifications

The admin console (`lib/main_admin.dart`, deployed under `/admin/`) has a
**Push notifications** tab for broadcasting a title, message, and optional app
URL to all opted-in web/PWA browsers. Sending requires Google sign-in and the
trusted Supabase `app_metadata.role = "admin"` role. The existing Notes tab is
unchanged; its table and Realtime configuration are still required to use it.

Before using notifications:

1. Apply
   [`20261015000001_web_push_subscriptions.sql`](supabase/migrations/20261015000001_web_push_subscriptions.sql)
   in the Supabase SQL editor. Users can manage only their own subscriptions;
   only the server-side service role can read the full recipient list.
2. Generate a VAPID key pair locally, for example with
   `npx web-push generate-vapid-keys`. Keep the private key secret.
3. Set Edge Function secrets using the Supabase CLI or dashboard:
   `VAPID_PUBLIC_KEY`, `VAPID_PRIVATE_KEY`, `VAPID_SUBJECT` (a `mailto:` contact),
   and `PUSH_APP_URL` (the HTTPS production app URL, including its base path
   and trailing slash, e.g. `https://fidoaf.github.io/popcorn_flutter/`).
   Supabase supplies `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY`.
4. Deploy with `supabase functions deploy send-push --no-verify-jwt`.
   The checked-in function configuration disables the gateway JWT check because
   the function itself verifies the bearer token with `auth.getUser` and checks
   the trusted admin role. It does **not** allow anonymous sends.
5. Grant the role to the intended admin in the SQL editor, preserving other
   metadata (replace the email):

   ```sql
   update auth.users
   set raw_app_meta_data = coalesce(raw_app_meta_data, '{}'::jsonb)
     || '{"role":"admin"}'::jsonb
   where email = 'admin@example.com';
   ```

   Sign out and back in after changing roles. Do not put this role in
   user-editable `user_metadata`. Add the deployed `/admin/` callback URL to
   Supabase Auth's allowed redirect URLs and enable Google OAuth.
6. Add **only the public key** as `push.vapidPublicKey=...` in
   `assets/config/app.env`, then rebuild/deploy the production and admin web apps
   using `build_web_all.ps1`. Never put a service-role key or VAPID private key in
   Flutter assets.

Signed-in users opt in/out with the notifications bell on the web home page.
HTTPS (or localhost for development), browser permission, and Web Push support
are required. On iPhone/iPad, install the PWA to the home screen first
(iOS/iPadOS 16.4+). Permission is never requested automatically. Unsupported
browsers and native apps do not display the bell.

The dedicated `push_service_worker.js` uses a `push/` scope under each web
build's base path; it is preserved by startup cache cleanup and receives pushes
without an open app tab. Clicks open an app URL on the same origin and inside
the configured app path. Leaving the optional URL blank opens the app; relative
URLs such as `#/home` are resolved against `PUSH_APP_URL`.

Results distinguish push-service acceptance, failed sends, expired
subscriptions (automatically deleted on HTTP 404/410), and no subscribers.
Acceptance does not guarantee that an offline/disabled device displays the
message. Subscriptions remain active after sign-out; sign in and use the bell
to disable them, or revoke permission in browser settings. Broadcasts are public
announcements, not private/account-specific messages. Notification
payloads are limited to 100 title characters, 1000 message characters, and
3072 UTF-8 bytes including the URL. Broadcasts run synchronously with bounded
concurrency; for large audiences, add a background delivery queue before
exceeding your Edge Function execution limits. A failed/timeout broadcast can
already have sent some messages, so inspect function logs before retrying.

Focused checks:

```powershell
flutter test test/push_notification_panel_test.dart
node --test tool/web_push.test.cjs supabase/functions/send-push/validation_test.ts
deno check --node-modules-dir=none --no-lock supabase/functions/send-push/index.ts
```

## Local App and Player

From the project root, start the player server in one terminal:

```powershell
npm --prefix server start
```

Run the Flutter web app in another terminal:

```powershell
flutter run -d chrome -t lib/main_web.dart --web-port 8080 --dart-define=PLAYER_SERVER_URL=http://localhost:3001
```

The app is available at http://localhost:8080 and embeds the local player server.
The launch option overrides only hosted `/player` providers; omitting it keeps
the production configuration unchanged. Restart the app when changing the
option. History still uses the configured Supabase database, so apply the
playback column migration and sign in to test resume persistence.

For an Android emulator, use `http://10.0.2.2:3001` as the player URL. For a
physical device, use your PC's LAN IP and allow access to port 3001 through the
firewall. Native mobile platforms may also require development-only HTTP
cleartext permissions. For web testing, use a local HTTP app rather than
embedding an HTTP player from a deployed HTTPS app.

## Player Server Authorization

In the Render service's **Environment** settings, set `API_TOKENS` to one or
more comma-separated bearer tokens, then redeploy. Multiple tokens allow a
new app token to be deployed before removing the old one. `AUTH_TOKEN` is also
accepted as a single-token fallback. The Render blueprint prompts for
`API_TOKENS`; do not put real tokens in source control. Use long random values
(for example, `node -e "console.log(require('node:crypto').randomBytes(32).toString('hex'))"`).

Set `playerServer.token=<matching-token>` in the app's environment configuration
(the existing `ENV_FILE`, `TEST_ENV_FILE`, or `ADMIN_ENV_FILE` GitHub secret
for the corresponding deployment). Keep local environment files out of source
control. Alternatively, build or run with
`--dart-define=PLAYER_SERVER_TOKEN=<matching-token>`; a non-empty build-time
value overrides the environment-file value. This applies to all Flutter
targets, including the existing web build scripts and Windows packaging.
Restart the app after changing its environment file; rebuild native packages
to distribute an updated file or compile-time value.

Use `--dart-define=PLAYER_SERVER_URL=https://your-service.onrender.com` when
overriding the configured player host. Restart/rebuild after changing a
compile-time value.

The app sends `Authorization: Bearer <token>` to `/watch-providers` and to
`/session`. The latter returns a random playback credential used in URLs
because browser iframes and native HLS requests cannot consistently attach
custom headers. Player navigation, manifests, segments, encryption keys,
and subtitles retain that session; the configured bearer token is not put
in their URLs or forwarded to upstream providers. Sessions expire after
30 minutes without a server request and are lost on server restart. Reopen
playback to obtain a new session after expiry or redeployment. Treat session
URLs as credentials as well.

All server routes require authorization except `/health`, `/favicon.ico`,
and CORS preflight (`OPTIONS`). Missing/invalid credentials return HTTP 401.
Without `API_TOKENS` or `AUTH_TOKEN`, authorization remains disabled for local
development. Deploy the updated server and app together when enabling it.

**Client tokens are not secrets:** users can extract tokens from distributed
native apps and web builds. This is a shared server access gate, not per-user
authentication. Use HTTPS in production and never reuse an administrative or
third-party API credential for this token.

## Cross-device Resume

Watch history stores the playback position, provider, source, audio language,
and subtitle selection in Supabase for the active profile. Sign in with the
same account and select the same profile on another device to resume. The app
reloads cloud history when opening playback. Changes to settings and completed
seeks are saved immediately; normal progress is saved every five seconds and
on pause. Completed videos resume from the beginning.

Before deploying this feature, apply
[`20261012000001_watch_history_playback_columns.sql`](supabase/migrations/20261012000001_watch_history_playback_columns.sql)
followed by
[`20261012000002_watch_history_resume_only.sql`](supabase/migrations/20261012000002_watch_history_resume_only.sql)
to the existing Supabase database, then deploy both the Flutter app and the
player server. The existing profile-scoped RLS policies and unique key on
`(profile_id, media_type, media_id)` are required. No Realtime publication is
needed. History writes update one title rather than replacing the entire list.

Playback settings use individual columns: `playback_provider`, `playback_source`,
`audio_language`, `subtitle_selection`, and `position_seconds`. Position is a
nonnegative, finite number of seconds. A null subtitle selection means no saved
choice; an empty string means subtitles are off. The follow-up migration copies
existing JSONB snapshots into these columns and drops the `playback` column.
Skip migrations that have already been applied. Older app versions that write
removed columns must be upgraded as well.

History stores only ownership, media identity, episode, playback settings,
position, and timestamp. The resume-only migration removes `title`, `overview`,
`poster_url`, `release_date`, and `vote_average` without removing history rows.
Display metadata is loaded from the catalog and cached in memory by media type
and ID. If the catalog is unavailable, entries still retain their resume state
and display their media ID until a later lookup succeeds.

The server player's gear, at the right end of the bottom status bar, opens provider, source, language, quality,
and subtitle settings. Redirect-only providers stay embedded inside this shell
so the provider selector remains available. Their language and subtitle
preferences are forwarded through the configured embed URL; actual support
depends on the provider. Source and quality selection remain inside the
external player when it does not expose a track API. Sites that block framing
cannot be embedded by this shell.

The hosted player and native player support session capture. Sources and
subtitles are matched against fresh catalogs instead of reusing expired IDs.
Unavailable sources fall back to automatic selection. External embedded
players without an event API cannot report their internal settings or position.
Uploaded local subtitle files are not transferred to other devices. Cloud
sync requires a network connection; simultaneous sessions use the last
successful write. Abrupt termination may lose the latest few seconds.

## Skip Intro and Next Episode

The hosted HTML player and media_kit player use the free
[IntroDB API](https://theintrodb.org/docs) to display floating **Skip intro**
buttons during known intro segments and **Next episode** buttons during
credits. Requests include the media ID, season/episode, and actual video
duration in milliseconds to identify the release. No IntroDB API key is needed.
The hosted player uses the server's `/introdb` endpoint; deploy the updated
player server together with the app.

Next episodes are verified against the catalog, including season rollover,
and unreleased episodes and series finales have no next-episode button.
Advancing starts the next episode at zero while retaining playback preferences
and updating watch history. The hosted next-episode action requires the app
to supply the verified next season/episode. Missing timestamps hide the
corresponding buttons; API failures are reported without stopping playback.
External provider iframes without a playback/seek API cannot use these controls.

The hosted player's **Fullscreen** / **Exit fullscreen** button expands the
whole player container, keeping Skip intro and Next episode visible and
clickable above the video controls. During fullscreen playback, Exit fullscreen
fades after three seconds of inactivity and reappears on pointer movement,
touch, or keyboard interaction. It remains visible while paused or keyboard-focused;
the skip buttons are unaffected. The video-only fullscreen shortcut is
hidden where the browser supports it. media_kit keeps the buttons in its
fullscreen window too. Browsers limited to native video-only fullscreen
(such as older iOS versions) cannot display HTML overlays there; use inline
playback for these buttons on those browsers.

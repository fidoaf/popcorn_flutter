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
   Supabase Auth's allowed redirect URLs and enable Email authentication and
   Google OAuth.
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

### Per-user Windows installer (no administrator access)

Native Google sign-in (Windows, Android and macOS) opens the system browser and
returns through `com.comacasaencaplloc.popcorn-flutter://login-callback/`
(hyphen, since underscores are not valid in URI schemes). Add that exact URL
to Supabase **Authentication > URL Configuration > Redirect URLs**. Both
Windows installers register the scheme, and the runner forwards callbacks to
the existing app instance, where Supabase exchanges the code and updates the
session. Install an updated package to apply protocol registration; rebuilding
or hot-reloading alone does not register a development executable.

Debug Windows builds (for example the **Popcorn Windows + Local Server** launch
configuration) register the same scheme under
`HKEY_CURRENT_USER\Software\Classes\com.comacasaencaplloc.popcorn-flutter`
for the running debug executable on startup. Reinstall or repair the installed
app afterwards to point the scheme back at the installed executable. Release or
profile builds run outside an installer still need that key registered manually
with an empty `URL Protocol` string and a `shell\open\command` default value of
`"C:\path\to\popcorn_flutter.exe" "%1"`.
Do not log callback URLs, which can contain authentication credentials.
If both MSIX and Inno copies are installed, Windows may route the protocol to
the other copy; use one installation for authentication testing.

GitHub Actions provides two independent, manually triggered workflows:

- **Package Windows app** builds MSIX/App Installer and deploys its downloads
  through GitHub Pages (including its automatic-update feed).
- **Package Windows app (Inno Setup)** builds the per-user EXE and uploads the
  `popcorn-windows-inno-installer` artifact. It publishes the versioned EXE and
  SHA-256 checksum to the app's `v<version>` GitHub Release.
- The MSIX workflow publishes the versioned MSIX, signing certificate, and
  checksums to that same release, while GitHub Pages continues to host the
  App Installer feed for automatic updates. The release assets also provide
  direct downloads. Re-running either workflow replaces its matching assets.
  Inno updates remain manual. Both workflows require release-write permission
  for their `GITHUB_TOKEN`.

The [Windows downloads page](https://fidoaf.github.io/popcorn_flutter/windows-downloads.html)
links to both installers and explains their different trust/update behavior.
Deploy Pages after adding this page, and run each packaging workflow at least
once to populate its downloads. Inno publication does not deploy Pages or
overwrite the MSIX installer/feed; normal Pages deployments preserve the
existing MSIX files. Both installers are listed under the same versioned
release on GitHub.

The Inno Setup installer installs to `%LOCALAPPDATA%\Programs\Popcorn`, creates a
current-user Start menu shortcut, offers an optional desktop shortcut, and
registers a current-user uninstaller. It includes the local server, Chromium,
and app-local Visual C++ runtime DLLs; no certificate import or elevation is
required. Hosted playback remains the default. Windows SmartScreen may warn
because this test installer is not signed by a trusted publisher.

To build it, install Inno Setup 6 and the Visual Studio C++ build tools, prepare
the server bundle, and run:

```powershell
.\tool\bundle_windows_server.ps1
.\tool\build_windows_installer.ps1
```

If the server bundle is already prepared, omit the first command. The installer
is written to `build\installer\Popcorn-<version>-Windows-x64-Setup.exe`.
The version comes from the release executable. Pass `-SkipBuild` to package an
existing release, `-CompilerPath` for a custom `ISCC.exe` location, or
`-VcRuntimeDirectory` for the Visual Studio x64 `Microsoft.VC143.CRT` directory.
Close Popcorn before upgrading or uninstalling. Uninstall removes installed
files and shortcuts but preserves application preferences. This installer is
separate from the MSIX package; uninstall either copy explicitly if both are
installed.

In VS Code, the **Build Windows Inno Setup installer (local)** and **Build
Windows MSIX (local)** launch configurations build either package. They prepare
the server bundle when it is missing. The MSIX
(`build\installer\Popcorn-<version>-Windows-x64.msix`, built by
`.\tool\build_windows_msix.ps1`) is signed with the msix package test
certificate, exported as `build\installer\Popcorn-test-certificate.cer`. Import
it into **Local Machine > Trusted People** before installing the MSIX.

### Optional bundled Windows server

Windows **Account settings > Use local player server** is off by default.
Enable it and restart the app to use the bundled server at `127.0.0.1:3000`.
Disable it and restart to return to the configured hosted server. The choice
applies to playback providers, Live TV, radio, and watch-provider lookups;
authentication, TMDB, and other internet services still require connectivity.

Local mode first checks server health and its authenticated provider catalogue.
It reuses a compatible server accepting this installation's randomly generated,
persisted token; otherwise it starts bundled Node.js without requiring a system
Node installation. The server binds only to loopback. A different or unauthorized
service on port 3000 is reported, not stopped or replaced. Local startup/runtime
errors offer **Disable local mode and use hosted server** instead of silently
switching backends. The application closes only its own server; the server also
shuts down when its parent's stdin pipe closes.

The Windows packaging workflow bundles Node.js, server production dependencies,
and Chromium for Puppeteer providers. This increases the installer size.
Runtime licenses/notices are retained in the bundle. To prepare a local build:

```powershell
.\tool\bundle_windows_server.ps1
flutter build windows --target lib\main_windows.dart
```

Run the bundler before building (including debug builds using local mode).
It stages files in `build\windows-server`; CMake installs them next to the app
under `local_server`, which MSIX includes. The bundler requires Windows x64
Node.js/npm and network access at build time, verifies the official Node archive
against its published SHA-256, and installs the Chromium version selected by the
locked Puppeteer dependency. It refuses to overwrite a nonempty staging folder;
explicitly remove that generated folder before preparing a fresh bundle.
The packaged app needs neither system Node.js nor system Chrome.

Focused checks:

```powershell
flutter test test\windows_local_server_test.dart test\local_server_settings_test.dart test\media_source_provider_test.dart
node --test server\test\managedServer.test.js
```

The bundled-process test runs only when the staged bundle exists.

Closing a video player restores the application out of playback fullscreen,
including when navigating Back to details. Native WebView and media-kit players
wait for pending fullscreen requests before restoring the window; the web iframe
player exits browser fullscreen when it is removed. Inline playback does not
change the window state when closed.

### GitHub Pages environment configuration

The Pages workflow replaces the built web configuration with the GitHub Actions
`ENV_FILE` secret before publishing. Set that secret to the **complete multiline
contents** of your local `assets/config/app.env`, not just a newly added setting.
In particular, retain `supabase.url`, `supabase.publishableKey`, and
`tmdb.accessToken` when adding `playerServer.token` or `push.vapidPublicKey`.
Only client-safe credentials belong in this file: never include a Supabase
service-role key or a VAPID private key.

Optional `TEST_ENV_FILE` and `ADMIN_ENV_FILE` secrets replace the entire
configuration for their respective builds; when unset, they use `ENV_FILE`.
The workflow rejects missing/empty Supabase settings before uploading the site.
If the published app reports missing Supabase configuration, correct the
appropriate secret in GitHub **Settings > Secrets and variables > Actions**,
then rerun **Deploy static content to Pages**. Changing the secret alone does
not update the existing deployment. No Flutter rebuild is needed when only
these runtime configuration values change.

In VS Code select **Popcorn Web + Local Server** in **Run and
Debug** and press **F5** to launch both processes. This uses the local-only
development token `dev-token` on both sides, with the server on port 3000 and
the web app on port 8080. The app's compile-time token overrides any token in
its environment file. Stopping the compound session stops both processes.
Do not use this development token for a deployed server.

Alternatively, from the project root, start the player server in one terminal:

```powershell
npm --prefix server start
```

Run the Flutter web app in another terminal:

```powershell
flutter run -d chrome -t lib/main_web.dart --web-port 8080 --dart-define=PLAYER_SERVER_URL=http://localhost:3001
```

The app is available at http://localhost:8080 and embeds the local player server.
The launch option overrides hosted `/player` providers and the server used for
Live TV and watch-provider lookups; omitting it keeps the production
configuration unchanged. Restart the app when changing the
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

Radio stations appear below Live TV at the bottom of the home page. The
authenticated `GET /radio` endpoint fetches up to 60 popular, working stations
from [Radio Browser](https://api.radio-browser.info/) and caches them for an hour.
The server discovers and randomizes API mirrors using Radio Browser's DNS SRV
records and retries other mirrors on upstream errors. No API key is needed;
the app uses its existing player-server bearer token.
The radio header has a searchable country selector with flags and localized
names (English, Spanish, Catalan), initially set to "All countries". Selecting
a country requests `/radio?country=ES`, filtering Radio Browser before its
60-station limit. Country choices come from Radio Browser's full country-code
directory, not just the initial stations. Clearing restores all countries.
Home search includes a **Radio stations** chip. Station names are searched
case-insensitively via `/radio?q=...`, forwarded to Radio Browser's name search
before the 60-result limit. Typing is debounced; results open the radio player.
Radio search has independent state from the home row's country selection and
includes clear, empty, error and retry states.
Country lists and per-country/search results are cached for an hour (up to 32 result
sets); radio and Live TV country selections are independent.
Station cards show the station logo (or a radio placeholder), name and country.
Opening a card navigates to `/radio/{stationUuid}`, with play/pause and volume
controls powered by media-kit. Playback stops when leaving this page.
Deep links resolve station metadata independently of the home row.
On Play, `GET /radio/play?station={stationUuid}` resolves the stream and reports
the listening click using Radio Browser's `/json/url` endpoint; browsing does
not report clicks. Pausing and resuming does not report another click.
Loading, empty, error and retry states are localized in English, Spanish and
Catalan. Streams play directly: browser codec, mixed-content, CORS and regional
restrictions can still prevent individual stations from playing.

Live TV uses `GET /live-tv` on this same player server. The server fetches and
caches the iptv-org catalogue for six hours, and the app sends the configured
player-server bearer token with catalogue requests. Channel logos come from
iptv-org's `logos.json` URL field, matched to the stream's channel and feed
(falling back to a channel-wide logo). Within each match, current logos are
preferred, then horizontal and white variants for the dark cards. The app
renders SVG and raster logo URLs.
When iptv-org labels the selected stream as `Geo-blocked`, channel cards show
a localized geographic-restriction warning and details explain that playback
may be unavailable in your location. This is upstream metadata, not a check
of your location; playback remains available to try. Missing labels do not
guarantee worldwide availability.
Details also show the selected feed's published broadcast area from
`feeds.json`, resolving countries, regions, subdivisions, and cities using
iptv-org metadata. Country names follow the app language; other place names
use their published names (unrecognized area codes are shown as-is).
Broadcast areas are not treated as streaming allowlists. For geo-blocked streams,
details show "May be restricted to [channel country]" using a localized country
name, explicitly marked as inferred rather than verified. If the channel has
no country, details state that exact geographic restrictions are not provided.
No area is inferred from the channel's country or a different feed.
The channel card opens `/live-tv/{channelId}` for details; its separate Play
button opens `/live-tv/{channelId}/watch` directly. The Live TV header's country
selector shows country flags and names in the app's language (English,
Spanish, or Catalan) and supports case-insensitive searching
by country name or two-letter code. Typing only filters the menu; choosing an
entry applies the channel filter. It starts with no country selected
("All countries"); selecting a country filters the server's full cached
catalogue before the 60-channel row limit. Choosing "All countries" clears the
filter. Available countries come from channels with streams, not just the
initial row.
Home search also offers a **Live TV** choice chip alongside Movies and TV
Series. Channel names and IDs are searched case-insensitively across the full
catalogue via `/live-tv?q=...`, before the 60-result limit. Search uses its own
state, independent of the home row's country selection. Channel results retain
separate Details and Play actions.
Details include an EPG at the bottom, loaded via the authenticated `/live-tv/epg?channel={channelId}`
endpoint. EPG data comes from [IPTV-EPG Guides](https://iptv-epg.org/guides).
The server discovers the site's published country-specific XMLTV links and
selects the channel's country guide, cached for 15 minutes. It matches an exact
channel/feed XMLTV ID first, then a channel ID, then a unique display name
(ignoring the guide's country prefix). Ambiguous name matches are not merged.
The country guide directory is cached for six hours.
Country guides are parsed incrementally, retaining up to 100 current/upcoming
programmes per XMLTV channel rather than caching the entire XML document.
Programme times use the viewer's local timezone. Channels without a published
guide or current listings show an explicit unavailable message; source failures
show a retry action.
Restart the Node server
after updating its code. If `/live-tv` returns 401, ensure the app's
`playerServer.token` or `PLAYER_SERVER_TOKEN` matches a token in the server's
`API_TOKENS`; no authentication exemption is required.

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
`audio_language`, `subtitle_selection`, `subtitle_delay_seconds`, and `position_seconds`. Position is a
nonnegative, finite number of seconds. A null subtitle selection means no saved
choice; an empty string means subtitles are off. The follow-up migration copies
existing JSONB snapshots into these columns and drops the `playback` column.
Skip migrations that have already been applied. Older app versions that write
removed columns must be upgraded as well.

Apply [`20261018000001_watch_history_subtitle_delay.sql`](supabase/migrations/20261018000001_watch_history_subtitle_delay.sql)
before deploying subtitle timing persistence. The signed offset is saved with
the language and subtitle selection for each profile and title, including
half-second adjustments. Positive values delay subtitles; negative values
advance them. Existing entries default to zero. Both the native and hosted
players restore the offset on resume and carry it forward with language
preferences when moving to another episode.

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
[IntroDB API v4](https://theintrodb.org/docs) to display floating **Skip intro**
buttons during known intro segments and **Next episode** buttons during
credits. If credits timestamps are unavailable, Next episode appears during the
last 20 seconds of a TV episode, provided a released next episode exists.
Requests include the media ID, season/episode, and actual video
duration in milliseconds to identify the release. No IntroDB API key is needed.
Both players request `/v4/media`. TMDB (or IMDb for hosted sources) identifiers
remain supported request parameters; v4 responses identify media by `tvdb_id`.
The players read the unchanged segment arrays without depending on a response
TMDB ID. TV requests retain the catalog's season/episode numbering, which v4
resolves from the supplied provider ID; no media-server display-order override
is applied.
The hosted player uses the server's `/introdb` endpoint; deploy the updated
player server together with the app.

Next episodes are verified against the catalog, including season rollover,
and unreleased episodes and series finales have no next-episode button.
The button reads **Next season** when the target is in a later season, and
**Next episode** when it is in the current season.
Advancing replaces the current watch route, including its browser history
entry, so Back returns directly to the page that opened playback.
Advancing starts the next episode at zero while retaining playback preferences
and updating watch history. The hosted next-episode action requires the app
to supply the verified next season/episode. Missing intro timestamps hide
Skip intro; missing credits use the last-20-second fallback. API failures are
reported without stopping playback.
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

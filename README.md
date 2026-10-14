# popcorn_flutter
Watch movies and TV series on the go!

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

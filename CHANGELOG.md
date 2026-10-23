# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.10.1]

### Changed
- Updated intro and credits timestamp lookup to IntroDB API v4.
- Windows release workflows now use the updated Flutter SDK and display the app version on the downloads page.

## [1.10.0]

### Added
- Windows MSIX and per-user installers with an optional bundled local player server.
- Native Windows Google sign-in callback handling.

### Changed
- Windows account settings can switch between local and hosted player servers.

## [1.9.3]

### Added
- Radio station-name search in the home search overlay, alongside movies, TV series, and Live TV.

### Changed
- Radio search now filters upstream results and caches them by search query and country.

### Fixed
- Closing playback now exits fullscreen reliably across supported players.

## [1.9.2]

### Added
- Radio station browsing with country filtering, station details, and playback controls.
- Radio Browser-backed station discovery with cached country lists and station catalogues.

### Changed
- Added Radio to the home page below Live TV.

## [1.9.1]

### Added
- Email and password sign-in alongside Google authentication.
- Account setting to choose the streaming availability region or use the device region.
- Saved subtitle timing preferences that are restored with playback sessions.

### Changed
- Live TV details now show localized country and broadcast-area information, including geo-restriction notices when available.
- Improved home-feed labels for newly released series and seasons.

## [1.9.0]

### Added
- Live TV channel browsing with country filters, search, programme guides, and playback.
- Fullscreen playback controls for skipping intros and moving to the next episode.
- Subtitle timing adjustment and automatic retries for playback load errors.

### Changed
- Improved player overlays and fullscreen behavior across supported platforms.

## [1.8.1]

### Changed
- Added validation for required Supabase configuration before GitHub Pages deployment.

## [1.8.0]

### Added
- Web push notifications for opted-in browsers.
- Admin console for sending push notifications to web and PWA users.

## [1.7.1]

### Added
- Web app installation prompt with browser-specific instructions.
- Home-feed badges for new movies, series, and seasons.

### Changed
- Enriched and cached TV series release metadata used by the home feed.
- Improved player close-button placement on narrow screens.

## [1.7.0]

### Added
- Intro and credits skip controls using IntroDB timestamps.
- Next-episode playback for TV series.
- Playback-session resume, including position and provider, source, language, and subtitle preferences.

### Changed
- Improved web update detection using the version embedded in the running build.

## [1.6.3]

### Added
- Playback settings for provider, language, source, quality, and subtitles in the hosted player.
- A close control for the hosted player.

### Changed
- Improved player startup and playback controls.

## [1.6.1]

### Added
- JustWatch links to regional streaming providers.

### Changed
- Improved watch-history synchronization and media detail provider presentation.

## [1.6.0]

### Added
- Playback-session details to watch history, enabling playback preferences and progress to be restored.

### Changed
- Improved watch-history loading, updates, and persistence.

## [1.5.3]

### Added
- Person detail pages with biographies, personal details, and notable credits.
- Regional streaming provider availability on media detail pages.
- Provider selection in the integrated media player.

### Changed
- Updated home search to expand in place and remain accessible while browsing.

## [1.5.2]

### Added
- Trending trailers section.
- Subtitle track selection in the media player.
- Additional media providers and provider selection in the player.

### Changed
- Improved login profile selection and logout navigation.
- Fixed soft keyboard issues and refined media details presentation.
- Updated Windows packaging and deployment workflows.

## [1.5.1]

### Added
- Additional language-specific and self-hosted media providers.

### Changed
- Improved server configuration and media source handling.

## [1.5.0]

### Added
- New server-backed media player implementation.
- Windows installer support.

### Changed
- Refactored player and server integration, including subtitle handling.

## [1.4.0]

### Changed
- Improved app navigation and player startup behavior.
- Updated Windows build and packaging pipelines.

## [1.3.0]

### Added
- Media provider selection, allowing users to choose their preferred media source provider.
- Rich details on the media details page.
- Integrated media player, including a proof-of-concept player that opens in a new tab.
- Node.js backend server with Docker support for containerized deployment.
- Extraction handling via a dedicated `/proxy-m3u8` endpoint with a total extraction timeout.

### Changed
- Improved in-app navigation.
- Refactored server logic and simplified the `/player` endpoint.
- Reduced server memory usage with a smaller base image in the Dockerfile.
- Changed the default media provider.
- General stability and usability improvements.
- Added heavy server-side logging for easier diagnostics.

## [1.2.0]

### Added
- Multi-profile accounts with avatar customisation and per-device profile selection.
- Prime-like home feed experience.
- Updated banner and refreshed home layout.

### Fixed
- Avatar profile switching.
- Missing startup error configuration in the main entry files.

## [1.1.0]

### Added
- User authentication and login page (Supabase-based sign in).
- Landing page and dedicated home page.
- Admin dashboard.
- Share functionality with a share button.
- Privacy Policy and Terms & Conditions.
- Google site verification process.
- Separate test environment with GitHub Pages deployment.

### Changed
- Authenticated users are taken straight to the home screen.
- Improved provider configuration and login design.

### Fixed
- Sign-in redirect via Supabase.
- Share registrant and share button issues.
- Sign-in error message display.

## [1.0.0]

### Added
- Initial Flutter application across web, Android, iOS, macOS and Windows targets.

### Changed
- Multiple web-focused improvements and restrictions.
- Blocked new windows (ads) and applied additional web restrictions.
- Updated theme color for web.

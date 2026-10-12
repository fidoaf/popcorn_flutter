# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

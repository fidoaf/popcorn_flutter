# Builds the production, test and admin Flutter web apps into docs/ for GitHub Pages.
# Production -> docs/            (https://fidoaf.github.io/popcorn_flutter/)
# Test       -> docs/test/      (https://fidoaf.github.io/popcorn_flutter/test/)
# Admin      -> docs/admin/     (https://fidoaf.github.io/popcorn_flutter/admin/)
#
# `flutter build web --output docs` wipes docs/, so production MUST build first,
# then the test/admin builds go into temp dirs and are copied into docs/.

$ErrorActionPreference = 'Stop'

# Compiled into the bundle so the update banner can detect a stale cached build.
$appVersion = ((Select-String -Path pubspec.yaml -Pattern '^version:\s*(\S+)').Matches[0].Groups[1].Value -split '\+')[0]

Write-Host "Building production web $appVersion (docs/) ..." -ForegroundColor Cyan
flutter build web -t lib/main_web.dart --base-href /popcorn_flutter/ --output docs --pwa-strategy=none --dart-define=APP_VERSION=$appVersion

Write-Host 'Done. Commit docs/ and push to deploy the main site.' -ForegroundColor Green

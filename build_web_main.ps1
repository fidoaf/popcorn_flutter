# Builds the production, test and admin Flutter web apps into docs/ for GitHub Pages.
# Production -> docs/            (https://fidoaf.github.io/popcorn_flutter/)
# Test       -> docs/test/      (https://fidoaf.github.io/popcorn_flutter/test/)
# Admin      -> docs/admin/     (https://fidoaf.github.io/popcorn_flutter/admin/)
#
# `flutter build web --output docs` wipes docs/, so production MUST build first,
# then the test/admin builds go into temp dirs and are copied into docs/.

$ErrorActionPreference = 'Stop'

Write-Host 'Building production web (docs/) ...' -ForegroundColor Cyan
flutter build web -t lib/main_web.dart --base-href /popcorn_flutter/ --output docs --pwa-strategy=none

Write-Host 'Done. Commit docs/ and push to deploy the main site.' -ForegroundColor Green

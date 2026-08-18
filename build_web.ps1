# Builds both the production and test Flutter web apps into docs/ for GitHub Pages.
# Production -> docs/            (https://fidoaf.github.io/popcorn_flutter/)
# Test       -> docs/test/      (https://fidoaf.github.io/popcorn_flutter/test/)
#
# `flutter build web --output docs` wipes docs/, so production MUST build first,
# then the test build goes into a temp dir and is copied into docs/test.

$ErrorActionPreference = 'Stop'

Write-Host 'Building production web (docs/) ...' -ForegroundColor Cyan
flutter build web -t lib/main_web.dart --base-href /popcorn_flutter/ --output docs --pwa-strategy=none

Write-Host 'Building test web (build/web_test) ...' -ForegroundColor Cyan
flutter build web -t lib/main_test.dart --base-href /popcorn_flutter/test/ --output build/web_test --pwa-strategy=none

Write-Host 'Copying test build into docs/test/ ...' -ForegroundColor Cyan
if (Test-Path docs/test) { Remove-Item docs/test -Recurse -Force }
Copy-Item build/web_test docs/test -Recurse -Force

Write-Host 'Done. Commit docs/ and push to deploy both sites.' -ForegroundColor Green

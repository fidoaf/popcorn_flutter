# Builds the production, test and admin Flutter web apps into docs/ for GitHub Pages.
# Production -> docs/            (https://fidoaf.github.io/popcorn_flutter/)
# Test       -> docs/test/      (https://fidoaf.github.io/popcorn_flutter/test/)
# Admin      -> docs/admin/     (https://fidoaf.github.io/popcorn_flutter/admin/)
#
# `flutter build web --output docs` wipes docs/, so production MUST build first,
# then the test/admin builds go into temp dirs and are copied into docs/.

$ErrorActionPreference = 'Stop'

Write-Host 'Building test web (build/web_test) ...' -ForegroundColor Cyan
flutter build web -t lib/main_test.dart --base-href /popcorn_flutter/test/ --output build/web_test --pwa-strategy=none

Write-Host 'Copying test build into docs/test/ ...' -ForegroundColor Cyan
if (Test-Path docs/test) { Remove-Item docs/test -Recurse -Force }
Copy-Item build/web_test docs/test -Recurse -Force

Write-Host 'Done. Commit docs/ and push to deploy the test site.' -ForegroundColor Green

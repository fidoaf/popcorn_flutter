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

Write-Host 'Building test web (build/web_test) ...' -ForegroundColor Cyan
flutter build web -t lib/main_test.dart --base-href /popcorn_flutter/test/ --output build/web_test --pwa-strategy=none

Write-Host 'Copying test build into docs/test/ ...' -ForegroundColor Cyan
if (Test-Path docs/test) { Remove-Item docs/test -Recurse -Force }
Copy-Item build/web_test docs/test -Recurse -Force

Write-Host 'Building admin web (build/web_admin) ...' -ForegroundColor Cyan
flutter build web -t lib/main_admin.dart --base-href /popcorn_flutter/admin/ --output build/web_admin --pwa-strategy=none

Write-Host 'Copying admin build into docs/admin/ ...' -ForegroundColor Cyan
if (Test-Path docs/admin) { Remove-Item docs/admin -Recurse -Force }
Copy-Item build/web_admin docs/admin -Recurse -Force

Write-Host 'Done. Commit docs/ and push to deploy all sites.' -ForegroundColor Green

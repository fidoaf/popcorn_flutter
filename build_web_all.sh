#!/usr/bin/env bash
# Builds the production, test and admin Flutter web apps into docs/ for GitHub Pages.
# Production -> docs/            (https://fidoaf.github.io/popcorn_flutter/)
# Test       -> docs/test/      (https://fidoaf.github.io/popcorn_flutter/test/)
# Admin      -> docs/admin/     (https://fidoaf.github.io/popcorn_flutter/admin/)
#
# `flutter build web --output docs` wipes docs/, so production MUST build first,
# then the test/admin builds go into temp dirs and are copied into docs/.

set -euo pipefail

# Compiled into the bundle so the update banner can detect a stale cached build.
app_version="$(awk '$1 == "version:" { split($2, version, "[+]"); print version[1]; exit }' pubspec.yaml)"
if [[ -z "$app_version" ]]; then
	printf 'Could not read the app version from pubspec.yaml.\n' >&2
	exit 1
fi

printf "Building production web %s (docs/) ...\n" "$app_version"
flutter build web -t lib/main_web.dart --base-href /popcorn_flutter/ --output docs --pwa-strategy=none --dart-define=APP_VERSION="$app_version"

printf 'Building test web (build/web_test) ...\n'
flutter build web -t lib/main_test.dart --base-href /popcorn_flutter/test/ --output build/web_test --pwa-strategy=none

printf 'Copying test build into docs/test/ ...\n'
rm -rf docs/test
cp -R build/web_test docs/test

printf 'Building admin web (build/web_admin) ...\n'
flutter build web -t lib/main_admin.dart --base-href /popcorn_flutter/admin/ --output build/web_admin --pwa-strategy=none

printf 'Copying admin build into docs/admin/ ...\n'
rm -rf docs/admin
cp -R build/web_admin docs/admin

printf 'Done. Commit docs/ and push to deploy all sites.\n'

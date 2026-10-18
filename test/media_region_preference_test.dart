import 'package:flutter_test/flutter_test.dart';
import 'package:popcorn_flutter/src/search/domain/media_region_preference.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('uses the device region when no override is saved', () async {
    expect(await MediaRegionPreference.currentRegion(), MediaRegionPreference.deviceRegion);
  });

  test('persists an override as an uppercase country code', () async {
    await MediaRegionPreference.setRegion('es');

    expect(await MediaRegionPreference.savedRegion(), 'ES');
    expect(await MediaRegionPreference.currentRegion(), 'ES');
  });

  test('clears the override to return to the device region', () async {
    await MediaRegionPreference.setRegion('FR');
    await MediaRegionPreference.setRegion(null);

    expect(await MediaRegionPreference.savedRegion(), isNull);
    expect(await MediaRegionPreference.currentRegion(), MediaRegionPreference.deviceRegion);
  });
}

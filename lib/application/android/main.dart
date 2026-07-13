import 'package:popcorn_flutter/application/android/app_configuration.dart';
import 'package:popcorn_flutter/common/constants.dart';

import 'app.dart';

void main(List<String> args) async {
  final app = await AndroidApplication.run(configuration: AndroidApplicationConfiguration(title: TITLE));
  app.ready.then((ready) {
    if (ready) {
      app.goToMainPage();
    }
  });
}

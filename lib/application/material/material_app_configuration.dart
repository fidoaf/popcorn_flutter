import 'package:flutter/foundation.dart';
import 'package:popcorn_flutter/application/domain/application_configuration.dart';

abstract class MaterialApplicationConfiguration extends ApplicationConfiguration {
  MaterialApplicationConfiguration({required super.title, bool? showDebugIndication}) : super(showDebugIndication: showDebugIndication ?? kDebugMode);
}

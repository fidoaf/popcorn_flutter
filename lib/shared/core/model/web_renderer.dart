import 'package:popcorn_flutter/player/core/model/web_content_render_settings.dart';

abstract class IWebRenderer {
  Future<bool> launch(WebContentRenderSettings settings);
  Future<bool> check(WebContentRenderSettings settings);

  const IWebRenderer();
}
import 'package:popcorn_flutter/player/view/details_mixin.dart';
import 'package:popcorn_flutter/favorite/view/favorite_mixin.dart';
import 'package:popcorn_flutter/player/view/player_mixin.dart';

class MediaDetailsController with DetailsMixin, FavoriteMixin, PlayerMixin {
  MediaDetailsController();
}

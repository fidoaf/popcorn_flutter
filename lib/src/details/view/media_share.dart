import 'package:flutter/widgets.dart';
import 'package:popcorn_flutter/src/app/routing/app_routes.dart';
import 'package:popcorn_flutter/src/details/view/details_translations.dart';
import 'package:popcorn_flutter/src/locale/view/locale_formatting.dart';
import 'package:popcorn_flutter/src/locale/view/translation_context_extension.dart';
import 'package:popcorn_flutter/src/search/domain/media_item.dart';
import 'package:popcorn_flutter/src/search/domain/media_type.dart';
import 'package:share_plus/share_plus.dart';

/// Public web deployment that resolves the in-app `#/watch/...` deep link.
const _watchSiteBase = 'https://fidoaf.github.io/popcorn_flutter/';

/// Opens the platform share sheet for [item], sharing its TMDB page link plus
/// a direct "watch now" deep link into the Popcorn web app.
Future<void> shareMedia(BuildContext context, MediaItem item, MediaType type) {
  final path = type == MediaType.movie ? 'movie' : 'tv';
  final url = 'https://www.themoviedb.org/$path/${item.id}';
  final overview = item.overview.trim();
  final summary = overview.isEmpty ? '' : '$overview\n';
  final tail = item.isReleased
      ? '${DetailsTranslations.watchNow.trOf(context)}\n$_watchSiteBase#${AppRoutes.watch(type, item.id)}'
      : _releaseStatus(context, item);
  final text = '${item.title}\n$summary$url\n\n$tail';
  final box = context.findRenderObject() as RenderBox?;
  return SharePlus.instance.share(
    ShareParams(text: text, subject: item.title, sharePositionOrigin: box != null ? box.localToGlobal(Offset.zero) & box.size : null),
  );
}

String _releaseStatus(BuildContext context, MediaItem item) {
  final date = item.releaseDate;
  if (date == null) return DetailsTranslations.comingSoon.trOf(context);
  return '${DetailsTranslations.outOn.trOf(context)} ${context.formatDate(date)}';
}

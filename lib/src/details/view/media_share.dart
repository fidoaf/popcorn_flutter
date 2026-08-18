import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
///
/// When the platform has no share sheet available (e.g. desktop browsers
/// without the Web Share API), it falls back to copying the text to the
/// clipboard so the action never surfaces an uncaught error.
Future<void> shareMedia(BuildContext context, MediaItem item, MediaType type) async {
  final path = type == MediaType.movie ? 'movie' : 'tv';
  final url = 'https://www.themoviedb.org/$path/${item.id}';
  final overview = item.overview.trim();
  final summary = overview.isEmpty ? '' : '$overview\n';
  final tail = item.isReleased
      ? '${DetailsTranslations.watchNow.trOf(context)}\n$_watchSiteBase#${AppRoutes.watch(type, item.id)}'
      : _releaseStatus(context, item);
  final text = '${item.title}\n$summary$url\n\n$tail';
  final box = context.findRenderObject() as RenderBox?;
  final messenger = ScaffoldMessenger.maybeOf(context);
  final copiedMessage = DetailsTranslations.linkCopied.trOf(context);
  try {
    await SharePlus.instance.share(
      ShareParams(
        text: text,
        subject: item.title,
        sharePositionOrigin: box != null ? box.localToGlobal(Offset.zero) & box.size : null,
        downloadFallbackEnabled: false,
        mailToFallbackEnabled: false,
      ),
    );
  } catch (e) {
    log('Failed to share media: $e', name: 'shareMedia');
    await Clipboard.setData(ClipboardData(text: text));
    messenger?.showSnackBar(SnackBar(content: Text(copiedMessage)));
  }
}

String _releaseStatus(BuildContext context, MediaItem item) {
  final date = item.releaseDate;
  if (date == null) return DetailsTranslations.comingSoon.trOf(context);
  return '${DetailsTranslations.outOn.trOf(context)} ${context.formatDate(date)}';
}

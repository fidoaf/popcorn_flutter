import 'package:flutter_test/flutter_test.dart';
import 'package:popcorn_flutter/app/core/application_configuration.dart';
import 'package:popcorn_flutter/search/core/model/media_type.dart';
import 'package:popcorn_flutter/search/core/use_case/search_media_info.dart';
import 'package:popcorn_flutter/search/tools/omdb/omdb_media_search.dart';

void main() {
  const searcher = SearchMediaInfo(searcher: OMDBSearcher(secretKey: omdbKeySecret));

  group('Media searcher', () {
    test('Empty search generates no results', () async {
      final result = await searcher.searchMedia(query: '');
      expect(result.items, []);
      expect(result.errors == null, false);
    });

    test('Unkwown text generates no results', () async {
      final result = await searcher.searchMedia(query: 'asdalksdjalksdjalsj');
      expect(result.items, []);
      expect(result.errors == null, false);
    });

    test('Matching text generates results', () async {
      final result = await searcher.searchMedia(query: 'Minions');
      expect(result.items.isNotEmpty, true);
      expect(result.errors == null, true);
    });

    test('Matching text with specific type generates results', () async {
      final result = await searcher.searchMedia(query: 'Severance', type: MediaType.series);
      expect(result.items.isNotEmpty, true);
      expect(result.errors == null, true);
    });
  });
}



// {Title: Severance, Year: 2022–, imdbID: tt11280740, Type: series, Poster: https://m.media-amazon.com/images/M/MV5BZDI5YzJhODQtMzQyNy00YWNmLWIxMjUtNDBjNjA5YWRjMzExXkEyXkFqcGc@._V1_SX300.jpg}









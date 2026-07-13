import 'package:popcorn_flutter/common/application/result.dart';
import 'package:popcorn_flutter/common/application/use_case.dart';
import 'package:popcorn_flutter/favorite/domain/favorite_item.dart';

typedef FavoriteListFetcherParams = ();

class FavoriteListFetcher implements UseCase<FavoriteListFetcherParams, Iterable<FavoriteItem>> {
  @override
  Future<Result<Iterable<FavoriteItem>>> call(FavoriteListFetcherParams params) async {
    try {
      final list = await Future.delayed(
          const Duration(seconds: 1),
          () => <FavoriteItem>[
                FavoriteItem.create(title: 'Silo', year: '2023'),
              ]);
      return Result.success(list);
      return Result.failure(Exception('null'));
    } on Exception catch (ex) {
      return Result.failure(ex);
    }
  }
}

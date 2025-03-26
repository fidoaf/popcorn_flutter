import 'package:popcorn_flutter/storage/tools/storage_handler.dart';

class FavoriteStorageClient extends MediaStorageClient {
  const FavoriteStorageClient();

  @override
  String get key => 'favorites';
}

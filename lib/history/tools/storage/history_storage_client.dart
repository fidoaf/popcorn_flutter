import 'package:popcorn_flutter/storage/tools/storage_handler.dart';

class HistoryStorageClient extends MediaStorageClient {
  const HistoryStorageClient();

  @override
  String get key => 'history';
}

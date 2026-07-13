import 'package:popcorn_flutter/common/application/result.dart';

abstract class UseCase<I, O> {
  Future<Result<O>> call(I params);
}

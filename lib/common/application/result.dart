abstract class Result<V> {
  factory Result.success(V value) {
    return OK(value: value);
  }

  factory Result.failure(Exception ex) {
    return Error(message: ex.toString());
  }
}

class OK<V> implements Result<V> {
  final V _value;
  OK({
    required V value,
  }) : _value = value;

  V get value => _value;
}

class Error<V> implements Result<V> {
  final String _message;
  Error({
    required String message,
  }) : _message = message;

  String get message => _message;
}

/// Result wrapper for operations that can succeed or fail
/// 
/// This provides a type-safe way to handle success/failure without exceptions.
library;

class Result<T> {
  final T? data;
  final String? error;
  final bool success;
  
  const Result.success(this.data) 
      : success = true, 
        error = null;
  
  const Result.failure(this.error) 
      : success = false, 
        data = null;
  
  bool get isSuccess => success;
  bool get isFailure => !success;
  
  /// Transform success data
  Result<R> map<R>(R Function(T data) transform) {
    if (isSuccess && data != null) {
      try {
        return Result.success(transform(data as T));
      } catch (e) {
        return Result.failure(e.toString());
      }
    }
    return Result.failure(error ?? 'No data');
  }
  
  /// Get data or default value
  T getOrElse(T defaultValue) {
    return data ?? defaultValue;
  }
  
  /// Get data or throw
  T getOrThrow() {
    if (isSuccess && data != null) {
      return data as T;
    }
    throw Exception(error ?? 'Operation failed');
  }
  
  @override
  String toString() {
    if (isSuccess) {
      return 'Result.success($data)';
    }
    return 'Result.failure($error)';
  }
}

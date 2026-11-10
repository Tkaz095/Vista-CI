enum LoadStatus { loading, success, empty, error }

/// A resource snapshot. Refresh/error may retain previously loaded data.
class AsyncState<T> {
  factory AsyncState.resolve({
    required T data,
    required bool loading,
    required bool empty,
    String error = '',
  }) {
    if (loading) return AsyncState.loading(data);
    if (error.isNotEmpty) return AsyncState.error(error, data);
    return empty ? AsyncState.empty(data) : AsyncState.success(data);
  }
  const AsyncState.loading([this.data])
    : status = LoadStatus.loading,
      message = '';
  const AsyncState.success(T value)
    : status = LoadStatus.success,
      data = value,
      message = '';
  const AsyncState.empty([this.data]) : status = LoadStatus.empty, message = '';
  const AsyncState.error(this.message, [this.data]) : status = LoadStatus.error;

  final LoadStatus status;
  final T? data;
  final String message;
  bool get isLoading => status == LoadStatus.loading;
  bool get isEmpty => status == LoadStatus.empty;
  bool get hasError => status == LoadStatus.error;
}

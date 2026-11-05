import 'package:flutter/foundation.dart';

import '../../core/state/async_state.dart';
import '../../core/telemetry/app_telemetry.dart';
import '../../data/models/feature_config.dart';
import '../../data/services/remote_config_service.dart';

class AppConfigViewModel extends ChangeNotifier {
  AppConfigViewModel(this._source, {this.telemetry});
  final RemoteConfigSource _source;
  final AppTelemetry? telemetry;
  AsyncState<FeatureConfig> state = const AsyncState.empty(
    FeatureConfig.defaults,
  );
  FeatureConfig get config => state.data ?? FeatureConfig.defaults;
  bool _disposed = false;
  Future<void> refresh() async {
    if (_disposed || state.isLoading) return;
    state = AsyncState.loading(config);
    notifyListeners();
    try {
      final result = await _source.fetch();
      if (_disposed) return;
      state = AsyncState.success(result);
    } catch (error, stack) {
      if (_disposed) return;
      telemetry?.nonFatal(error, stack, AppOperation.remoteConfig);
      state = const AsyncState.error(
        'Chưa cập nhật được cấu hình. Đang dùng giá trị mặc định.',
        FeatureConfig.defaults,
      );
    }
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

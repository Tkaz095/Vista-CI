import 'package:flutter/foundation.dart';

import '../../core/telemetry/app_telemetry.dart';

class DiagnosticsViewModel extends ChangeNotifier {
  DiagnosticsViewModel({this.telemetry, this.onCrash});
  final AppTelemetry? telemetry;
  final VoidCallback? onCrash;
  String message = '';
  void testNonFatal() {
    if (!kDebugMode || telemetry == null) return;
    try {
      throw StateError('intentional_debug_test');
    } catch (error, stack) {
      telemetry!.nonFatal(error, stack, AppOperation.debugTest);
    }
    message = 'Đã xếp hàng lỗi thử nghiệm. Kiểm tra báo cáo trên Crashlytics.';
    notifyListeners();
  }

  void testCrash() {
    if (!kDebugMode) return;
    onCrash?.call();
  }
}

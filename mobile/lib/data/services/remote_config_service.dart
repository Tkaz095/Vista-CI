import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

import '../models/feature_config.dart';

abstract interface class RemoteConfigSource {
  Future<FeatureConfig> fetch();
}

class RemoteConfigService implements RemoteConfigSource {
  final FirebaseRemoteConfig _config = FirebaseRemoteConfig.instance;
  @override
  Future<FeatureConfig> fetch() async {
    await _config.setDefaults(FeatureConfig.parameters);
    await _config.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: kDebugMode
            ? Duration.zero
            : const Duration(hours: 12),
      ),
    );
    await _config.fetchAndActivate();
    return FeatureConfig.fromStrings({
      for (final key in FeatureConfig.parameters.keys)
        key: _config.getString(key),
    });
  }
}

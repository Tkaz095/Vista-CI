class FeatureConfig {
  const FeatureConfig({
    this.analysisEnabled = true,
    this.cloudinaryCloudName = '',
    this.cloudinaryUploadPreset = '',
  });
  final bool analysisEnabled;
  final String cloudinaryCloudName;
  final String cloudinaryUploadPreset;
  static const defaults = FeatureConfig();
  static const parameters = <String, Object>{
    'ci_analysis_enabled': true,
    'cloudinary_cloud_name': '',
    'cloudinary_upload_preset': '',
  };
  factory FeatureConfig.fromStrings(Map<String, String> values) {
    final enabled = switch (values['ci_analysis_enabled']
        ?.toLowerCase()
        .trim()) {
      'true' || '1' => true,
      'false' || '0' => false,
      _ => true,
    };
    return FeatureConfig(
      analysisEnabled: enabled,
      cloudinaryCloudName: values['cloudinary_cloud_name']?.trim() ?? '',
      cloudinaryUploadPreset: values['cloudinary_upload_preset']?.trim() ?? '',
    );
  }
}

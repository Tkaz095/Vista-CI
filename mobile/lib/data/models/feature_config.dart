class FeatureConfig {
  const FeatureConfig({this.analysisEnabled = true, this.repoPageSize = 5});
  final bool analysisEnabled;
  final int repoPageSize;
  static const defaults = FeatureConfig();
  static const parameters = <String, Object>{
    'ci_analysis_enabled': true,
    'project_repo_page_size': 5,
  };
  factory FeatureConfig.fromStrings(Map<String, String> values) {
    final enabled = switch (values['ci_analysis_enabled']
        ?.toLowerCase()
        .trim()) {
      'true' || '1' => true,
      'false' || '0' => false,
      _ => true,
    };
    final count = int.tryParse(values['project_repo_page_size'] ?? '') ?? 5;
    return FeatureConfig(
      analysisEnabled: enabled,
      repoPageSize: count.clamp(1, 20),
    );
  }
}

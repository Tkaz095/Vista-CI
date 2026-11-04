/// Public identifiers for the unsigned PDF preset. No API secret is used in app.
class CloudinaryOptions {
  const CloudinaryOptions({
    this.cloudName = const String.fromEnvironment('CLOUDINARY_CLOUD_NAME'),
    this.uploadPreset = const String.fromEnvironment(
      'CLOUDINARY_UPLOAD_PRESET',
    ),
  });
  final String cloudName;
  final String uploadPreset;
  bool get configured =>
      RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(cloudName) &&
      uploadPreset.trim().isNotEmpty;
  Uri get uploadUrl =>
      Uri.https('api.cloudinary.com', '/v1_1/$cloudName/raw/upload');
}

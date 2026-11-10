enum CiNotificationMode {
  failures('failures', 'Chỉ khi CI lỗi'),
  results('results', 'Kết quả CI'),
  all('all', 'Bắt đầu và kết quả'),
  off('off', 'Tắt thông báo repo này');

  const CiNotificationMode(this.value, this.label);
  final String value;
  final String label;
  static CiNotificationMode parse(String value) =>
      values.firstWhere((mode) => mode.value == value);
}

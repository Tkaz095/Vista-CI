class NotificationTarget {
  const NotificationTarget({
    required this.repoId,
    required this.repoFullName,
    required this.runId,
    required this.attempt,
  });
  final int repoId;
  final String repoFullName;
  final int runId;
  final int attempt;

  static NotificationTarget? parse(Map<String, dynamic> data) {
    int? positive(String key) {
      final value = int.tryParse('${data[key] ?? ''}');
      return value != null && value > 0 && value <= 9007199254740991
          ? value
          : null;
    }

    final repoId = positive('repo_id');
    final runId = positive('run_id');
    final attempt = positive('attempt');
    final name = data['repo_full_name'];
    if (repoId == null ||
        runId == null ||
        attempt == null ||
        name is! String ||
        name.length > 201 ||
        !RegExp(r'^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$').hasMatch(name) ||
        name.split('/').any((part) => part == '.' || part == '..')) {
      return null;
    }
    return NotificationTarget(
      repoId: repoId,
      repoFullName: name,
      runId: runId,
      attempt: attempt,
    );
  }

  Map<String, String> toData() => {
    'repo_id': '$repoId',
    'repo_full_name': repoFullName,
    'run_id': '$runId',
    'attempt': '$attempt',
  };
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.uid,
    required this.title,
    required this.body,
    required this.receivedAt,
    this.target,
    this.read = false,
    this.phase,
  });
  final String id;
  final String uid;
  final String title;
  final String body;
  final DateTime receivedAt;
  final NotificationTarget? target;
  final bool read;
  final String? phase;
  String get systemTag => target == null
      ? id
      : 'ci_${target!.repoId}_${target!.runId}_${target!.attempt}';

  static AppNotification? parse(
    Map<String, dynamic> data, {
    String? messageId,
    String? title,
    String? body,
    DateTime? sentAt,
  }) {
    final id = data['notification_id'] ?? messageId;
    final uid = data['uid'];
    if (id is! String ||
        !RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(id) ||
        uid is! String ||
        uid.isEmpty ||
        uid.length > 128 ||
        uid.contains('/')) {
      return null;
    }
    String bounded(Object? value, int limit, String fallback) {
      final text = value is String && value.trim().isNotEmpty
          ? value.trim()
          : fallback;
      return String.fromCharCodes(text.runes.take(limit));
    }

    return AppNotification(
      id: id,
      uid: uid,
      title: bounded(title ?? data['title'], 200, 'Thông báo CI'),
      body: bounded(body ?? data['body'], 1000, ''),
      receivedAt:
          DateTime.tryParse('${data['received_at'] ?? ''}') ??
          sentAt ??
          DateTime.now(),
      target: data['type'] == 'workflow_run'
          ? NotificationTarget.parse(data)
          : null,
      read: data['read'] == true,
      phase: ['started', 'completed'].contains(data['phase'])
          ? data['phase'] as String
          : null,
    );
  }

  AppNotification asRead() => AppNotification(
    id: id,
    uid: uid,
    title: title,
    body: body,
    receivedAt: receivedAt,
    target: target,
    read: true,
    phase: phase,
  );

  Map<String, dynamic> toJson() => {
    'notification_id': id,
    'uid': uid,
    'title': title,
    'body': body,
    'received_at': receivedAt.toUtc().toIso8601String(),
    'read': read,
    if (phase != null) 'phase': phase,
    if (target != null) ...{'type': 'workflow_run', ...target!.toData()},
  };
}

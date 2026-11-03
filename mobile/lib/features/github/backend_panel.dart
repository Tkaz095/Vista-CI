import 'package:flutter/material.dart';

import '../../core/backend_client.dart';
import 'github_repository.dart';

class BackendPanel extends StatefulWidget {
  const BackendPanel({super.key, required this.onChanged});
  final VoidCallback onChanged;
  @override
  State<BackendPanel> createState() => _BackendPanelState();
}

class _BackendPanelState extends State<BackendPanel> {
  final url = TextEditingController();
  Map<String, dynamic>? info;
  bool busy = false, confirming = false;
  String error = '', message = '';
  @override
  void initState() {
    super.initState();
    initialize();
  }

  Future<void> initialize() async {
    final saved = await BackendClient.origin();
    if (!mounted) return;
    url.text = saved;
    if (url.text.isEmpty) return;
    await action('info');
  }

  Future<void> action(String kind) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = '';
      message = '';
    });
    try {
      final repo = GitHubRepository.instance;
      Map<String, dynamic>? next;
      if (kind == 'save') {
        await BackendClient.saveOrigin(url.text);
        repo.clear();
        next = await repo.connectionInfo();
      } else if (kind == 'disconnect') {
        final text = await repo.disconnect();
        if (mounted) {
          message = text;
          confirming = false;
        }
        next = {'connected': false};
      } else if (kind == 'refresh') {
        next = await repo.refreshConnection();
      } else if (kind == 'connect') {
        await repo.connect(false);
        next = await repo.connectionInfo();
      } else {
        next = await repo.connectionInfo();
      }
      if (mounted) {
        setState(() => info = next);
        if (kind != 'info') widget.onChanged();
      }
    } catch (cause) {
      if (mounted) {
        setState(
          () => error = cause.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  String date(dynamic milliseconds) => milliseconds is num
      ? DateTime.fromMillisecondsSinceEpoch(milliseconds.toInt())
            .toLocal()
            .toString()
            .split('.')
            .first
      : '—';
  @override
  void dispose() {
    GitHubRepository.instance.cancelConnection();
    url.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Backend và kết nối GitHub',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          const Text(
            'Web và app dùng chung kết nối theo tài khoản Firebase. Chỉ nhập backend Vista do bạn quản lý; app sẽ gửi Firebase ID token tới địa chỉ này.',
          ),
          const SizedBox(height: 8),
          const Text(
            'Tải log CI/CD cần cấp quyền public_repo qua Kết nối GitHub. Quyền OAuth này bao gồm đọc và ghi repo public. Nếu gặp lỗi 403, kết nối lại để duyệt quyền bổ sung; gia hạn token không bổ sung quyền mới.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: url,
            enabled: !busy,
            decoration: const InputDecoration(
              labelText: 'URL backend Vista',
              hintText: 'https://vista-ci.web.app',
            ),
            keyboardType: TextInputType.url,
          ),
          OutlinedButton(
            onPressed: busy ? null : () => action('save'),
            child: const Text('Lưu URL backend'),
          ),
          if (info != null) ...[
            Text(
              info!['connected'] == true
                  ? 'Đã lưu kết nối · tự gia hạn'
                  : 'Chưa có kết nối GitHub hợp lệ',
            ),
            if (info!['login'] != null) Text('GitHub: ${info!['login']}'),
            if (info!['connected'] == true) ...[
              Text('Access token đến hạn: ${date(info!['expiresAt'])}'),
              Text('Refresh token đến hạn: ${date(info!['refreshExpiresAt'])}'),
            ],
          ],
          FilledButton(
            onPressed: busy ? null : () => action('connect'),
            child: const Text('Kết nối GitHub qua trình duyệt'),
          ),
          OutlinedButton(
            onPressed: busy ? null : () => action('refresh'),
            child: const Text('Cập nhật kết nối'),
          ),
          if (info?['connected'] == true && !confirming)
            TextButton(
              onPressed: busy ? null : () => setState(() => confirming = true),
              child: const Text('Ngắt kết nối'),
            ),
          if (confirming) ...[
            const Text(
              'Ngắt trên mọi thiết bị Vista và xóa token backend? Ứng dụng sẽ yêu cầu GitHub thu hồi quyền OAuth của Vista; phiên Firebase hiện tại được giữ.',
            ),
            FilledButton(
              onPressed: busy ? null : () => action('disconnect'),
              child: const Text('Xác nhận ngắt kết nối'),
            ),
            TextButton(
              onPressed: busy ? null : () => setState(() => confirming = false),
              child: const Text('Hủy'),
            ),
          ],
          if (busy) const LinearProgressIndicator(),
          if (busy && GitHubRepository.instance.connecting)
            TextButton(
              onPressed: GitHubRepository.instance.cancelConnection,
              child: const Text('Hủy chờ kết nối'),
            ),
          if (message.isNotEmpty)
            Semantics(liveRegion: true, child: Text(message)),
          if (error.isNotEmpty)
            Semantics(
              liveRegion: true,
              child: Text(
                error,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
        ],
      ),
    ),
  );
}

import 'package:flutter/material.dart';

import 'session_view_model.dart';

class ScrollPage extends StatelessWidget {
  const ScrollPage({super.key, required this.children, this.eager = false});
  final List<Widget> children;
  final bool eager;
  @override
  Widget build(BuildContext context) {
    final items = children
        .map(
          (child) =>
              Padding(padding: const EdgeInsets.only(bottom: 20), child: child),
        )
        .toList();
    // Keep every form field mounted so validation also covers offscreen inputs.
    if (eager) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: items,
        ),
      );
    }
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.all(24),
      children: items,
    );
  }
}

class StatusPage extends StatelessWidget {
  const StatusPage({
    super.key,
    required this.title,
    required this.message,
    this.actions = const [],
  });
  final String title, message;
  final List<Widget> actions;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Vista CI')),
    body: SafeArea(
      child: ScrollPage(
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          Text(message),
          ...actions,
        ],
      ),
    ),
  );
}

class LogoutButton extends StatefulWidget {
  const LogoutButton({super.key, required this.repository});
  final AuthRepository repository;
  @override
  State<LogoutButton> createState() => _LogoutButtonState();
}

class _LogoutButtonState extends State<LogoutButton> {
  bool pending = false;
  Future<void> logout() async {
    setState(() => pending = true);
    try {
      await widget.repository.logout();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(authMessage(error))));
      }
    } finally {
      if (mounted) setState(() => pending = false);
    }
  }

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: pending ? null : logout,
    icon: const Icon(Icons.logout),
    label: Text(pending ? 'Đang đăng xuất…' : 'Đăng xuất'),
  );
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.repository});
  final AuthRepository repository;
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final form = GlobalKey<FormState>();
  final email = TextEditingController(), password = TextEditingController();
  bool pending = false, hidden = true;
  String error = '';
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (pending || !form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      pending = true;
      error = '';
    });
    try {
      await widget.repository.login(email.text, password.text);
    } catch (cause) {
      if (mounted) setState(() => error = authMessage(cause));
    } finally {
      if (mounted) setState(() => pending = false);
    }
  }

  Future<void> github() async {
    if (pending) return;
    FocusScope.of(context).unfocus();
    setState(() {
      pending = true;
      error = '';
    });
    try {
      await widget.repository.loginWithGitHub();
    } catch (cause) {
      if (mounted) setState(() => error = authMessage(cause));
    } finally {
      if (mounted) setState(() => pending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Vista CI')),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: AutofillGroup(
            child: Form(
              key: form,
              child: ScrollPage(
                eager: true,
                children: [
                  const Icon(
                    Icons.hub_outlined,
                    size: 52,
                    color: Color(0xFF2563EB),
                  ),
                  Text(
                    'Đăng nhập Vista',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const Text(
                    'Theo dõi workspace, repository và các lần chạy CI/CD của nhóm.',
                  ),
                  FilledButton(
                    onPressed: pending ? null : github,
                    child: Text(
                      pending ? 'Đang xác thực…' : 'Tiếp tục với GitHub',
                    ),
                  ),
                  const Text(
                    'Đã có tài khoản Email/Password? Đăng nhập bên dưới một lần, vào Tài khoản → Liên kết GitHub để giữ hồ sơ và workspace.',
                  ),
                  TextFormField(
                    controller: email,
                    enabled: !pending,
                    autofillHints: const [AutofillHints.username],
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    decoration: const InputDecoration(labelText: 'Email'),
                    validator: (value) =>
                        value == null ||
                            !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                .hasMatch(value.trim())
                        ? 'Nhập email hợp lệ.'
                        : null,
                  ),
                  TextFormField(
                    controller: password,
                    enabled: !pending,
                    obscureText: hidden,
                    autocorrect: false,
                    enableSuggestions: false,
                    autofillHints: const [AutofillHints.password],
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => submit(),
                    decoration: InputDecoration(
                      labelText: 'Mật khẩu',
                      suffixIcon: IconButton(
                        tooltip: hidden ? 'Hiện mật khẩu' : 'Ẩn mật khẩu',
                        onPressed: () => setState(() => hidden = !hidden),
                        icon: Icon(
                          hidden
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                    validator: (value) => value == null || value.isEmpty
                        ? 'Nhập mật khẩu.'
                        : null,
                  ),
                  if (error.isNotEmpty)
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        error,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  OutlinedButton(
                    onPressed: pending ? null : submit,
                    child: Text(pending ? 'Đang đăng nhập…' : 'Đăng nhập'),
                  ),
                  const Text(
                    'Đăng nhập bằng GitHub để bắt đầu. Vista tự tạo hồ sơ cơ bản cho tài khoản mới; quyền workspace được cấp riêng.',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class GitHubAccountActions extends StatefulWidget {
  const GitHubAccountActions({super.key, required this.repository});
  final AuthRepository repository;
  @override
  State<GitHubAccountActions> createState() => _GitHubAccountActionsState();
}

class _GitHubAccountActionsState extends State<GitHubAccountActions> {
  late bool linked = widget.repository.githubLinked;
  bool pending = false;
  String message = '';
  Future<void> act({required bool linking}) async {
    if (pending) return;
    setState(() {
      pending = true;
      message = '';
    });
    try {
      if (linking) {
        await widget.repository.linkGitHub();
        if (mounted) {
          setState(() {
            linked = widget.repository.githubLinked;
            message =
                'Đã liên kết GitHub. UID và quyền workspace được giữ nguyên.';
          });
        }
      } else {
        await widget.repository.logout();
      }
    } catch (cause) {
      if (mounted) {
        setState(() {
          linked = widget.repository.githubLinked;
          message = authMessage(cause);
        });
      }
    } finally {
      if (mounted) setState(() => pending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Divider(),
      const SizedBox(height: 16),
      Text('Đăng nhập GitHub', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 12),
      Text(
        linked ? 'Đã liên kết GitHub với tài khoản Vista này.' : 'Liên kết GitHub để đăng nhập lần sau bằng GitHub và giữ nguyên UID hiện tại.',
      ),
      const SizedBox(height: 16),
      if (!linked)
        FilledButton(
          onPressed: pending ? null : () => act(linking: true),
          child: Text(pending ? 'Đang xử lý…' : 'Liên kết GitHub'),
        ),
      if (message.isNotEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Semantics(liveRegion: true, child: Text(message)),
        ),
      const SizedBox(height: 16),
      const Text(
        'Quyền repository và đồng bộ CI/CD sẽ được cấu hình ở bước kết nối GitHub App.',
      ),
      const SizedBox(height: 20),
      OutlinedButton.icon(
        onPressed: pending ? null : () => act(linking: false),
        icon: const Icon(Icons.logout),
        label: const Text('Đăng xuất'),
      ),
    ],
  );
}

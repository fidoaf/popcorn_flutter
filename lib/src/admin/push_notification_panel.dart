import 'package:flutter/material.dart';
import 'package:popcorn_flutter/src/auth/domain/auth_controller.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PushNotificationPanel extends StatefulWidget {
  const PushNotificationPanel({super.key, required this.client});

  final SupabaseClient client;

  @override
  State<PushNotificationPanel> createState() => _PushNotificationPanelState();
}

class _PushNotificationPanelState extends State<PushNotificationPanel> {
  late final AuthController _auth = AuthController(client: widget.client);

  @override
  void initState() {
    super.initState();
    _auth.addListener(_checkOAuthError);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _checkOAuthError();
    });
  }

  void _checkOAuthError() {
    final error = _auth.consumeOAuthError();
    if (error != null) _showError(StateError(error), StackTrace.current);
  }

  @override
  void dispose() {
    _auth.removeListener(_checkOAuthError);
    _auth.dispose();
    super.dispose();
  }

  Future<void> _authenticate() async {
    try {
      final started = await _auth.signInWithGoogle();
      if (!started) throw StateError('Could not open Google sign-in.');
    } catch (error, stack) {
      _showError(error, stack);
    }
  }

  Future<void> _signOut() async {
    try {
      await _auth.signOut();
    } catch (error, stack) {
      _showError(error, stack);
    }
  }

  void _showError(Object error, StackTrace stack) {
    debugPrint('Admin authentication failed: $error\n$stack');
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
  }

  Future<PushSendResult> _send(String title, String body, String url) async {
    final response = await widget.client.functions.invoke('send-push', body: {'title': title, 'body': body, 'url': url});
    if (response.status != 200) throw StateError('Push function returned HTTP ${response.status}: ${response.data}');
    return PushSendResult.fromJson(response.data);
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _auth,
    builder: (context, _) {
      final user = _auth.user;
      if (user == null) {
        return Center(child: FilledButton.icon(onPressed: _authenticate, icon: const Icon(Icons.login), label: const Text('Sign in with Google to send push notifications')));
      }
      return Column(
        children: [
          ListTile(
            title: Text(user.email ?? 'Signed in'),
            trailing: TextButton(onPressed: _signOut, child: const Text('Sign out')),
          ),
          Expanded(
            child: user.appMetadata['role'] == 'admin'
                ? PushNotificationForm(onSend: _send)
                : const Center(child: Text('This account does not have admin access.')),
          ),
        ],
      );
    },
  );
}

class PushSendResult {
  const PushSendResult({required this.sent, required this.failed, required this.removed});

  factory PushSendResult.fromJson(dynamic data) {
    if (data is! Map<String, dynamic> ||
        data['sent'] is! int || data['failed'] is! int || data['removed'] is! int ||
        (data['sent'] as int) < 0 || (data['failed'] as int) < 0 || (data['removed'] as int) < 0) {
      throw const FormatException('Invalid push function response.');
    }
    return PushSendResult(sent: data['sent'] as int, failed: data['failed'] as int, removed: data['removed'] as int);
  }

  final int sent;
  final int failed;
  final int removed;
}

class PushNotificationForm extends StatefulWidget {
  const PushNotificationForm({super.key, required this.onSend});

  final Future<PushSendResult> Function(String title, String body, String url) onSend;

  @override
  State<PushNotificationForm> createState() => _PushNotificationFormState();
}

class _PushNotificationFormState extends State<PushNotificationForm> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _url = TextEditingController();
  bool _sending = false;
  String? _status;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _url.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _sending = true;
      _status = null;
    });
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Send to all subscribed browsers?'),
          content: const Text('This will broadcast the notification to every opted-in browser. It cannot be recalled.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Send now')),
          ],
        ),
      );
      if (confirmed != true) return;
      final result = await widget.onSend(_title.text.trim(), _body.text.trim(), _url.text.trim());
      if (!mounted) return;
      setState(() {
        _status = result.sent + result.failed + result.removed == 0
            ? 'No subscribed browsers. No notifications were sent.'
            : 'Accepted by push services: ${result.sent}. Failed: ${result.failed}. Expired subscriptions removed: ${result.removed}.';
      });
    } catch (error, stack) {
      debugPrint('Push broadcast failed: $error\n$stack');
      if (mounted) setState(() => _status = 'Unable to complete broadcast: $error');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String? _required(String? value, String label, int limit) {
    if (value == null || value.trim().isEmpty) return '$label is required.';
    if (value.trim().length > limit) return '$label must be at most $limit characters.';
    return null;
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Send push notification', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              const Text('Send an announcement to all opted-in web/PWA browsers, even when the app is closed. Push-service acceptance does not guarantee device delivery.'),
              const SizedBox(height: 24),
              TextFormField(
                controller: _title,
                enabled: !_sending,
                maxLength: 100,
                decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
                validator: (value) => _required(value, 'Title', 100),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _body,
                enabled: !_sending,
                maxLength: 1000,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(labelText: 'Message', border: OutlineInputBorder()),
                validator: (value) => _required(value, 'Message', 1000),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _url,
                enabled: !_sending,
                decoration: const InputDecoration(labelText: 'Open URL (optional)', helperText: 'An app URL or relative path. Leave empty to open the app.', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _sending ? null : _send,
                icon: _sending
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.send),
                label: Text(_sending ? 'Sending...' : 'Send to all subscribed browsers'),
              ),
              if (_status != null) ...[const SizedBox(height: 16), Text(_status!, key: const ValueKey('push-send-status'))],
            ],
          ),
        ),
      ),
    ),
  );
}

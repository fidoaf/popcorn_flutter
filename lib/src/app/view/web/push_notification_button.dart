import 'dart:convert';
import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:popcorn_flutter/src/app/translations/app_translations.dart';
import 'package:popcorn_flutter/src/locale/view/translation_context_extension.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

@JS('popcornPushSupported')
external JSBoolean _pushSupported();
@JS('popcornPushSubscription')
external JSPromise<JSString> _pushSubscription();
@JS('popcornPushPermission')
external JSPromise<JSAny?> _pushPermission();
@JS('popcornPushSubscribe')
external JSPromise<JSString> _pushSubscribe(JSString publicKey);
@JS('popcornPushUnsubscribe')
external JSPromise<JSAny?> _pushUnsubscribe();

class PushNotificationButton extends StatefulWidget {
  const PushNotificationButton({super.key});

  @override
  State<PushNotificationButton> createState() => _PushNotificationButtonState();
}

class _PushNotificationButtonState extends State<PushNotificationButton> {
  bool _busy = false;

  Future<void> _configure() async {
    setState(() => _busy = true);
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) throw StateError('Sign in to manage notifications.');
      final existing = (await _pushSubscription().toDart).toDart;
      String? endpoint;
      var enabled = false;
      if (existing.isNotEmpty) {
        endpoint = (jsonDecode(existing) as Map<String, dynamic>)['endpoint'] as String;
        final rows = await client.from('web_push_subscriptions').select('id').eq('endpoint', endpoint).eq('user_id', userId);
        enabled = rows.isNotEmpty;
      }
      final key = dotenv.env['push.vapidPublicKey'];
      if (!enabled && (key == null || key.isEmpty)) throw StateError('Missing push.vapidPublicKey configuration.');
      if (!mounted) return;
      Future<JSAny?>? permission;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(AppTranslations.pushTitle.trOf(context)),
          content: Text((enabled ? AppTranslations.pushDisableMessage : AppTranslations.pushEnableMessage).trOf(context)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(MaterialLocalizations.of(context).cancelButtonLabel)),
            FilledButton(
              onPressed: () {
                // Safari requires the permission request directly in the button gesture.
                if (!enabled) permission = _pushPermission().toDart;
                Navigator.pop(context, true);
              },
              child: Text((enabled ? AppTranslations.pushDisable : AppTranslations.pushEnable).trOf(context)),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      if (permission != null) await permission;
      if (client.auth.currentUser?.id != userId) throw StateError('The signed-in account changed. Please try again.');
      if (enabled) {
        await client.from('web_push_subscriptions').delete().eq('endpoint', endpoint!).eq('user_id', userId);
        await _pushUnsubscribe().toDart;
      } else {
        // A shared browser may still have a subscription belonging to a different account.
        if (existing.isNotEmpty && !enabled) await _pushUnsubscribe().toDart;
        final data = jsonDecode((await _pushSubscribe(key!.toJS).toDart).toDart) as Map<String, dynamic>;
        if (client.auth.currentUser?.id != userId) {
          await _pushUnsubscribe().toDart;
          throw StateError('The signed-in account changed. Please try again.');
        }
        final keys = data['keys'] as Map<String, dynamic>;
        await client.from('web_push_subscriptions').upsert({
          'user_id': userId,
          'endpoint': data['endpoint'] as String,
          'p256dh': keys['p256dh'] as String,
          'auth': keys['auth'] as String,
        }, onConflict: 'endpoint');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text((enabled ? AppTranslations.pushDisabled : AppTranslations.pushEnabled).trOf(context))));
    } catch (error, stack) {
      debugPrint('Push subscription failed: $error\n$stack');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${AppTranslations.pushError.trOf(context)} $error')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_pushSupported().toDart || Supabase.instance.client.auth.currentUser == null) return const SizedBox.shrink();
    return IconButton(
      tooltip: AppTranslations.pushTitle.trOf(context),
      onPressed: _busy ? null : _configure,
      icon: _busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.notifications_outlined),
    );
  }
}

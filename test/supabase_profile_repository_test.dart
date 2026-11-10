import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:popcorn_flutter/src/profile/infrastructure/supabase_profile_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('profile selection persists locally without changing the server default', () async {
    SharedPreferences.setMockInitialValues({});
    final client = SupabaseClient(
      'https://example.supabase.co',
      'test-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        dynamic body;
        if (request.url.path == '/auth/v1/token') {
          final email = (jsonDecode(request.body) as Map<String, dynamic>)['email'];
          final userId = email == 'other@example.com' ? 'user-2' : 'user-1';
          body = {
            'access_token': 'eyJhbGciOiJub25lIn0.eyJzdWIiOiJ1c2VyLTEifQ.',
            'token_type': 'bearer',
            'expires_in': 3600,
            'refresh_token': 'refresh-token',
            'user': {'id': userId, 'aud': 'authenticated', 'app_metadata': {}, 'user_metadata': {}, 'created_at': '2026-01-01T00:00:00Z'},
          };
        } else if (request.url.path.endsWith('/account_members')) {
          expect(request.method, 'GET');
          final userId = request.url.queryParameters['user_id'];
          expect(userId, anyOf('eq.user-1', 'eq.user-2'));
          if (request.url.queryParameters['select'] == 'account_id') {
            body = {'account_id': userId == 'eq.user-1' ? 'account-1' : 'account-2'};
          } else {
            body = {'default_profile_id': 'profile-1'};
          }
        } else if (request.url.path.endsWith('/profiles')) {
          final accountId = request.url.queryParameters['account_id']!.substring(3);
          final id = request.url.queryParameters['id']!.substring(3);
          body = id == 'outside' ? null : {'id': id, 'account_id': accountId, 'display_name': id};
        } else {
          fail('Unexpected request: ${request.method} ${request.url}');
        }
        return http.Response(jsonEncode(body), 200, headers: {'content-type': 'application/json'}, request: request);
      }),
    );
    addTearDown(client.dispose);
    await client.auth.signInWithPassword(email: 'user@example.com', password: 'password');

    final repository = SupabaseProfileRepository(client: client);
    expect((await repository.activeProfile())?.id, 'profile-1');
    await repository.setActiveProfile('profile-2');
    expect((await repository.activeProfile())?.id, 'profile-2');
    expect((await SupabaseProfileRepository(client: client).activeProfile())?.id, 'profile-2');

    await repository.setActiveProfile('outside');
    expect((await repository.activeProfile())?.id, 'profile-2');
    expect((await SupabaseProfileRepository(client: client).activeProfile())?.id, 'profile-2');

    await client.auth.signInWithPassword(email: 'other@example.com', password: 'password');
    expect((await repository.activeProfile())?.id, 'profile-1');
    await repository.setActiveProfile('profile-3');
    await client.auth.signInWithPassword(email: 'user@example.com', password: 'password');
    expect((await repository.activeProfile())?.id, 'profile-2');

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getString('profile.active.user-2.account-2'), 'profile-3');
    await preferences.setString('profile.active.user-1.account-1', 'outside');
    expect((await SupabaseProfileRepository(client: client).activeProfile())?.id, 'profile-1');
  });
}

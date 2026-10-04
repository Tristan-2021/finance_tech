import 'dart:async';
import 'dart:io';

import 'package:core_network/core_network.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('SupabaseConfig', () {
    // Corre sin --dart-define, por eso falla.
    test('fromEnvironment falla sin dart-define', () {
      expect(() => SupabaseConfig.fromEnvironment(), throwsStateError);
    });

    test('constructor guarda url y anonKey', () {
      const c = SupabaseConfig(url: 'http://x', anonKey: 'k');
      expect(c.url, 'http://x');
      expect(c.anonKey, 'k');
    });
  });

  group('retry', () {
    test('reintenta 503 y luego 200', () async {
      var calls = 0;
      final client = buildRetryClient(
        MockClient((_) async {
          calls++;
          if (calls < 3) return http.Response('busy', 503);
          return http.Response('ok', 200);
        }),
      );
      final r = await client.get(Uri.parse('http://x'));
      expect(r.statusCode, 200);
      expect(calls, 3);
    });

    test('no reintenta 500', () async {
      var calls = 0;
      final client = buildRetryClient(
        MockClient((_) async {
          calls++;
          return http.Response('err', 500);
        }),
      );
      final r = await client.get(Uri.parse('http://x'));
      expect(r.statusCode, 500);
      expect(calls, 1);
    });
  });

  group('mapToFailure', () {
    test('42501 -> rls_denied', () {
      final f = mapToFailure(
        PostgrestException(message: 'denied', code: '42501'),
      );
      expect(f.code, 'rls_denied');
      expect(f.message, 'Acceso denegado por RLS');
    });

    test('insufficient_funds en message', () {
      final f = mapToFailure(PostgrestException(message: 'insufficient_funds'));
      expect(f.code, 'insufficient_funds');
      expect(f.message, 'Saldo insuficiente');
    });

    test('insufficient_funds en code', () {
      final f = mapToFailure(
        PostgrestException(message: 'x', code: 'insufficient_funds'),
      );
      expect(f.code, 'insufficient_funds');
    });

    test('Postgrest desconocido -> unknown', () {
      final f = mapToFailure(
        PostgrestException(message: 'boom', code: '99999'),
      );
      expect(f.code, 'unknown');
      expect(f.message, 'boom');
    });

    test('AuthException -> auth', () {
      final f = mapToFailure(const AuthException('bad creds'));
      expect(f.code, 'auth');
      expect(f.message, 'bad creds');
    });

    test('SocketException -> network', () {
      expect(mapToFailure(const SocketException('no red')).code, 'network');
    });

    test('TimeoutException -> network', () {
      expect(mapToFailure(TimeoutException('slow')).code, 'network');
    });

    test('ClientException -> network', () {
      expect(mapToFailure(http.ClientException('fail')).code, 'network');
    });

    test('Exception genérica -> unknown', () {
      final f = mapToFailure(Exception('x'));
      expect(f.code, 'unknown');
      expect(f.message, contains('x'));
    });
  });
}

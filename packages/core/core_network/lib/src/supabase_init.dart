import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/retry.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'network_status_notifier.dart';
import 'observed_client.dart';
import 'supabase_config.dart';

/// Cliente con reintentos (3, backoff exponencial; 502/503/504 y errores de
/// red). [inner] es el cliente real; con un [FaultInjectingClient] los fallos
/// quedan dentro de los reintentos. Si hay [status], se le avisa de cada
/// reintento y de cuándo termina cada petición.
http.Client buildRetryClient([
  http.Client? inner,
  Duration Function(int retryCount)? delay,
  NetworkStatusNotifier? status,
]) {
  final retry = RetryClient(
    inner ?? http.Client(),
    retries: 3,
    when: (r) async =>
        r.statusCode == 502 || r.statusCode == 503 || r.statusCode == 504,
    whenError: (e, _) async =>
        e is http.ClientException ||
        e is SocketException ||
        e is TimeoutException,
    delay:
        delay ??
        (retryCount) => Duration(milliseconds: 200 * (1 << retryCount)),
    onRetry: status == null ? null : (_, _, _) => status.retryStarted(),
  );
  return status == null ? retry : ObservedClient(retry, status);
}

Future<SupabaseClient> initSupabase(
  SupabaseConfig config, {
  http.Client? innerClient,
  NetworkStatusNotifier? status,
}) async {
  await Supabase.initialize(
    url: config.url,
    publishableKey: config.publishableKey,
    httpClient: buildRetryClient(innerClient, null, status),
  );
  return Supabase.instance.client;
}

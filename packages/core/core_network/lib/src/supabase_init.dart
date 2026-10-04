import 'package:http/http.dart' as http;
import 'package:http/retry.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_config.dart';

RetryClient buildRetryClient([http.Client? inner]) {
  return RetryClient(
    inner ?? http.Client(),
    retries: 3,
    when: (r) async =>
        r.statusCode == 502 || r.statusCode == 503 || r.statusCode == 504,
    whenError: (e, _) async => e is http.ClientException,
    delay: (retryCount) => Duration(milliseconds: 200 * (1 << retryCount)),
  );
}

Future<SupabaseClient> initSupabase(SupabaseConfig config) async {
  await Supabase.initialize(
    url: config.url,
    anonKey: config.anonKey,
    httpClient: buildRetryClient(),
  );
  return Supabase.instance.client;
}

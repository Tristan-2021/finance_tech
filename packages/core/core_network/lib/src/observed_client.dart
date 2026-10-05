import 'package:http/http.dart' as http;

import 'network_status_notifier.dart';

/// Avisa a [NetworkStatusNotifier] cuándo empieza y termina cada petición.
class ObservedClient extends http.BaseClient {
  final http.Client _inner;
  final NetworkStatusNotifier _status;

  ObservedClient(this._inner, this._status);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    _status.requestStarted();
    try {
      return await _inner.send(request);
    } finally {
      _status.requestFinished();
    }
  }

  @override
  void close() => _inner.close();
}

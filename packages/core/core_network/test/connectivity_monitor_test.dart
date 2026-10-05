import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:core_network/core_network.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late StreamController<List<ConnectivityResult>> controller;
  late ConnectivityMonitor monitor;

  setUp(() {
    controller = StreamController<List<ConnectivityResult>>();
    monitor = ConnectivityMonitor(controller.stream);
  });

  test('onlineChanges traduce las interfaces y emite solo los cambios', () async {
    final values = monitor.onlineChanges.toList();

    controller
      ..add([ConnectivityResult.wifi])
      ..add([ConnectivityResult.mobile]) // sigue con red: no emite
      ..add([ConnectivityResult.none])
      ..add([ConnectivityResult.ethernet, ConnectivityResult.vpn]);
    await controller.close();

    expect(await values, [true, false, true]);
  });

  test('onReconnected emite solo al pasar de sin red a con red', () async {
    final reconnects = monitor.onReconnected.toList();

    controller
      ..add([ConnectivityResult.wifi]) // ya se asume con red: no cuenta
      ..add([ConnectivityResult.none])
      ..add([ConnectivityResult.wifi]) // recupera
      ..add([ConnectivityResult.mobile]) // sin cambio
      ..add([ConnectivityResult.none])
      ..add([ConnectivityResult.mobile]); // recupera otra vez
    await controller.close();

    expect((await reconnects).length, 2);
  });

  test('si nunca se pierde la red no hay reconexiones', () async {
    final reconnects = monitor.onReconnected.toList();

    controller.add([ConnectivityResult.wifi]);
    await controller.close();

    expect(await reconnects, isEmpty);
  });
}

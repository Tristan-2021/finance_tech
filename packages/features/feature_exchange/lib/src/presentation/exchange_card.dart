import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';

import 'exchange_cubit.dart';
import 'exchange_view.dart';

/// Bloque del home con el conversor de remesas [from] → [to]. Resuelve su
/// Cubit desde `GetIt.instance` (registrado por `registerExchangeDependencies`)
/// y lo cierra al salir.
class ExchangeCard extends StatefulWidget {
  final String from;
  final String to;

  const ExchangeCard({super.key, this.from = 'EUR', this.to = 'USD'});

  @override
  State<ExchangeCard> createState() => _ExchangeCardState();
}

class _ExchangeCardState extends State<ExchangeCard> {
  late final ExchangeCubit _cubit = GetIt.instance<ExchangeCubit>(
    param1: widget.from,
    param2: widget.to,
  );

  @override
  void initState() {
    super.initState();
    _cubit.load();
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExchangeView(cubit: _cubit);
}

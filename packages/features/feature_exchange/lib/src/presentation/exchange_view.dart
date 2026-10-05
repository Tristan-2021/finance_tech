import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/amount_input.dart';
import '../domain/convert_amount.dart';
import '../domain/exchange_rate.dart';
import 'exchange_cubit.dart';
import 'exchange_strings.dart';

/// Tarjeta del conversor. Recibe su [ExchangeCubit] (no usa GetIt) para
/// probarse sola; el estado de carga y de error van dentro de la tarjeta, así
/// que funciona en un contenedor sin alto acotado (el home).
class ExchangeView extends StatefulWidget {
  final ExchangeCubit cubit;
  const ExchangeView({super.key, required this.cubit});

  @override
  State<ExchangeView> createState() => _ExchangeViewState();
}

class _ExchangeViewState extends State<ExchangeView> {
  static const _convert = ConvertAmount();
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cubit = widget.cubit;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${ExchangeStrings.title} · '
              '${ExchangeStrings.pair(cubit.from, cubit.to)}',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            BlocBuilder<ExchangeCubit, ExchangeState>(
              bloc: cubit,
              builder: (context, state) => switch (state.status) {
                ExchangeStatus.loading => const SizedBox(
                  height: 96,
                  child: LoadingView(),
                ),
                ExchangeStatus.error => _ErrorBlock(
                  message: state.message!,
                  onRetry: cubit.load,
                ),
                ExchangeStatus.loaded => _Converter(
                  controller: _controller,
                  state: state,
                  rate: state.rate!,
                  convert: _convert,
                  onRetry: cubit.load,
                ),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBlock extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorBlock({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          liveRegion: true,
          child: Row(
            children: [
              ExcludeSemantics(
                child: Icon(Icons.error_outline, color: theme.colorScheme.error),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: Text(message, style: theme.textTheme.bodyMedium)),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AppButton(
          label: ExchangeStrings.retry,
          variant: AppButtonVariant.secondary,
          onPressed: onRetry,
        ),
      ],
    );
  }
}

class _Converter extends StatelessWidget {
  final TextEditingController controller;
  final ExchangeState state;
  final ExchangeRate rate;
  final ConvertAmount convert;
  final VoidCallback onRetry;

  const _Converter({
    required this.controller,
    required this.state,
    required this.rate,
    required this.convert,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cachedAt = state.cachedAt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (cachedAt != null) ...[
          Semantics(
            container: true,
            liveRegion: true,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ExcludeSemantics(child: Icon(Icons.history)),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    ExchangeStrings.staleNotice(formatDateEs(rate.date)),
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onRetry,
              child: const Text(ExchangeStrings.retry),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d{0,12}[.,]?\d{0,2}')),
          ],
          decoration: const InputDecoration(
            labelText: ExchangeStrings.amountLabel,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) {
            final cents = parseAmountInput(value.text);
            if (cents == null || cents == 0) {
              return Text(
                ExchangeStrings.amountHint,
                style: theme.textTheme.bodyMedium,
              );
            }
            final converted = formatCents(
              convert(cents, rate),
              currency: rate.target,
            );
            return Semantics(
              liveRegion: true,
              child: Text(
                ExchangeStrings.result(converted),
                style: theme.textTheme.headlineSmall,
              ),
            );
          },
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          ExchangeStrings.rateUsed(rate.base, rate.target, rate.shortRateText),
          style: theme.textTheme.bodySmall,
        ),
        Text(
          ExchangeStrings.rateDate(formatDateEs(rate.date)),
          style: theme.textTheme.bodySmall,
        ),
        Text(ExchangeStrings.dailyNote, style: theme.textTheme.bodySmall),
      ],
    );
  }
}

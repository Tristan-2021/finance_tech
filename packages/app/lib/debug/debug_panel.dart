import 'package:core_network/core_network.dart';
import 'package:core_storage/core_storage.dart';
import 'package:core_telemetry/core_telemetry.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

import 'debug_strings.dart';

/// Botón discreto y panel para inyectar latencia, fallos y desconexión, por
/// separado en cada servicio ([config] es el backend y [ratesConfig] el de
/// tasas), y para enviar un evento y un error de prueba a la telemetría. Solo
/// se debe crear en depuración (el shell lo comprueba con `kDebugMode`).
///
/// Vive por encima del `Navigator`, por eso no usa hojas ni menús emergentes.
class DebugPanelOverlay extends StatefulWidget {
  final DebugNetworkConfig config;
  final DebugNetworkConfig? ratesConfig;
  final Telemetry? telemetry;
  final CacheStore? cache;
  final Widget child;

  const DebugPanelOverlay({
    super.key,
    required this.config,
    required this.cache,
    required this.child,
    this.ratesConfig,
    this.telemetry,
  });

  @override
  State<DebugPanelOverlay> createState() => _DebugPanelOverlayState();
}

class _DebugPanelOverlayState extends State<DebugPanelOverlay> {
  /// Deja libre la barra inferior de navegación.
  static const _navBarClearance = 88.0;

  bool _open = false;
  String? _status;

  Future<void> _clearCache() async {
    await widget.cache?.clear();
    if (!mounted) return;
    setState(() => _status = DebugStrings.cacheCleared);
  }

  void _sendTestEvent() {
    widget.telemetry?.logEvent('debug_test_event', {'source': 'debug_panel'});
    setState(() => _status = DebugStrings.eventSent);
  }

  void _sendTestError() {
    widget.telemetry?.recordError(
      StateError('prueba'),
      StackTrace.current,
      reason: 'debug_panel_test_error',
    );
    setState(() => _status = DebugStrings.errorSent);
  }

  void _resetAll() {
    widget.config.reset();
    widget.ratesConfig?.reset();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned(
          right: AppSpacing.md,
          bottom: AppSpacing.md + _navBarClearance,
          child: SafeArea(
            child: Material(
              type: MaterialType.transparency,
              child: _open
                  ? _Panel(
                      config: widget.config,
                      ratesConfig: widget.ratesConfig,
                      status: _status,
                      onClose: () => setState(() {
                        _open = false;
                        _status = null;
                      }),
                      onReset: _resetAll,
                      onClearCache: widget.cache == null ? null : _clearCache,
                      onTestEvent: widget.telemetry == null
                          ? null
                          : _sendTestEvent,
                      onTestError: widget.telemetry == null
                          ? null
                          : _sendTestError,
                    )
                  // Sin `tooltip`: un Tooltip necesita un Overlay y este widget
                  // vive por encima del Navigator.
                  : Semantics(
                      label: DebugStrings.open,
                      button: true,
                      excludeSemantics: true,
                      child: IconButton.filledTonal(
                        icon: const Icon(Icons.bug_report_outlined),
                        onPressed: () => setState(() => _open = true),
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  final DebugNetworkConfig config;
  final DebugNetworkConfig? ratesConfig;
  final String? status;
  final VoidCallback onClose;
  final VoidCallback onReset;
  final VoidCallback? onClearCache;
  final VoidCallback? onTestEvent;
  final VoidCallback? onTestError;

  const _Panel({
    required this.config,
    required this.ratesConfig,
    required this.status,
    required this.onClose,
    required this.onReset,
    required this.onClearCache,
    required this.onTestEvent,
    required this.onTestError,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.8;
    final rates = ratesConfig;

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: 340, maxHeight: maxHeight),
      child: Material(
        elevation: 8,
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: ListenableBuilder(
            listenable: Listenable.merge([config, ?rates]),
            builder: (context, _) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        DebugStrings.title,
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    Semantics(
                      label: DebugStrings.close,
                      button: true,
                      excludeSemantics: true,
                      child: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: onClose,
                      ),
                    ),
                  ],
                ),
                _ServiceSection(title: DebugStrings.supabaseService, config: config),
                if (rates != null) ...[
                  const Divider(),
                  _ServiceSection(title: DebugStrings.ratesService, config: rates),
                ],
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    OutlinedButton(
                      onPressed: onReset,
                      child: const Text(DebugStrings.reset),
                    ),
                    OutlinedButton(
                      onPressed: onClearCache,
                      child: const Text(DebugStrings.clearCache),
                    ),
                  ],
                ),
                if (onTestEvent != null || onTestError != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(DebugStrings.monitoring, style: theme.textTheme.bodySmall),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      OutlinedButton(
                        onPressed: onTestEvent,
                        child: const Text(DebugStrings.testEvent),
                      ),
                      OutlinedButton(
                        onPressed: onTestError,
                        child: const Text(DebugStrings.testError),
                      ),
                    ],
                  ),
                ],
                if (status != null)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: Text(status!, style: theme.textTheme.bodySmall),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Interruptores de fallos de un servicio.
class _ServiceSection extends StatelessWidget {
  static const _failureOptions = [0, 25, 50, 100];

  final String title;
  final DebugNetworkConfig config;

  const _ServiceSection({required this.title, required this.config});

  static String _latencyLabel(Duration d) => d == Duration.zero
      ? DebugStrings.noLatency
      : DebugStrings.seconds(d.inSeconds);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleSmall),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text(DebugStrings.offline),
          value: config.offline,
          onChanged: (value) => config.offline = value,
        ),
        Text(DebugStrings.latency, style: theme.textTheme.bodySmall),
        const SizedBox(height: AppSpacing.xs),
        SegmentedButton<Duration>(
          showSelectedIcon: false,
          segments: [
            for (final d in DebugNetworkConfig.latencyOptions)
              ButtonSegment(value: d, label: Text(_latencyLabel(d))),
          ],
          selected: {config.latency},
          onSelectionChanged: (selection) => config.latency = selection.first,
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          DebugStrings.failures(config.failurePercent),
          style: theme.textTheme.bodySmall,
        ),
        // Segmentos y no un Slider: su indicador de valor necesita un Overlay y
        // este panel vive por encima del Navigator.
        SegmentedButton<int>(
          showSelectedIcon: false,
          emptySelectionAllowed: true,
          segments: [
            for (final p in _failureOptions)
              ButtonSegment(value: p, label: Text('$p %')),
          ],
          selected: _failureOptions.contains(config.failurePercent)
              ? {config.failurePercent}
              : <int>{},
          onSelectionChanged: (selection) {
            if (selection.isNotEmpty) config.failurePercent = selection.first;
          },
        ),
      ],
    );
  }
}

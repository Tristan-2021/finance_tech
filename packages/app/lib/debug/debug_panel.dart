import 'package:core_network/core_network.dart';
import 'package:core_storage/core_storage.dart';
import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

import 'debug_strings.dart';

/// Botón discreto y panel para inyectar latencia, fallos y desconexión. Solo se
/// debe crear en depuración (el shell lo comprueba con `kDebugMode`).
///
/// Vive por encima del `Navigator`, por eso no usa hojas ni menús emergentes.
class DebugPanelOverlay extends StatefulWidget {
  final DebugNetworkConfig config;
  final CacheStore? cache;
  final Widget child;

  const DebugPanelOverlay({
    super.key,
    required this.config,
    required this.cache,
    required this.child,
  });

  @override
  State<DebugPanelOverlay> createState() => _DebugPanelOverlayState();
}

class _DebugPanelOverlayState extends State<DebugPanelOverlay> {
  bool _open = false;
  bool _cacheCleared = false;

  Future<void> _clearCache() async {
    await widget.cache?.clear();
    if (!mounted) return;
    setState(() => _cacheCleared = true);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Positioned(
          right: AppSpacing.md,
          bottom: AppSpacing.md,
          child: SafeArea(
            child: Material(
              type: MaterialType.transparency,
              child: _open
                  ? _Panel(
                      config: widget.config,
                      cacheCleared: _cacheCleared,
                      onClose: () => setState(() {
                        _open = false;
                        _cacheCleared = false;
                      }),
                      onClearCache: widget.cache == null ? null : _clearCache,
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
  final bool cacheCleared;
  final VoidCallback onClose;
  final VoidCallback? onClearCache;

  const _Panel({
    required this.config,
    required this.cacheCleared,
    required this.onClose,
    required this.onClearCache,
  });

  static const _failureOptions = [0, 25, 50, 100];

  static String _latencyLabel(Duration d) =>
      d == Duration.zero
      ? DebugStrings.noLatency
      : DebugStrings.seconds(d.inSeconds);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.8;

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: 340, maxHeight: maxHeight),
      child: Material(
        elevation: 8,
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: ListenableBuilder(
            listenable: config,
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
                  onSelectionChanged: (selection) =>
                      config.latency = selection.first,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  DebugStrings.failures(config.failurePercent),
                  style: theme.textTheme.bodySmall,
                ),
                // Segmentos y no un Slider: su indicador de valor necesita un
                // Overlay y este panel vive por encima del Navigator.
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
                    if (selection.isNotEmpty) {
                      config.failurePercent = selection.first;
                    }
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    OutlinedButton(
                      onPressed: config.reset,
                      child: const Text(DebugStrings.reset),
                    ),
                    OutlinedButton(
                      onPressed: onClearCache,
                      child: const Text(DebugStrings.clearCache),
                    ),
                  ],
                ),
                if (cacheCleared)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: Text(
                      DebugStrings.cacheCleared,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

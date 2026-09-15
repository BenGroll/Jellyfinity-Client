import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../app/di/service_locator.dart';
import '../../../core/logging/LocalLogStore.dart';
import '../../../core/logging/Logger.dart';
import '../../../design/design.dart';

/// The in-app diagnostic log, opened by the sidebar's Logs > Remote entry.
///
/// Remote is selected first because it is the useful view while diagnosing
/// cross-device playback. All entries stay locally available too: the event
/// before a remote failure is often a session, lifecycle, or HTTP event.
class LogsPage extends StatefulWidget {
  const LogsPage({super.key, this.store});

  final LocalLogStore? store;

  @override
  State<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends State<LogsPage> {
  late final LocalLogStore _store = widget.store ?? getIt<LocalLogStore>();
  bool _remoteOnly = true;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return AppScaffold(
      title: 'Logs',
      padded: false,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () => context.pop(),
      ),
      actions: [
        IconButton(
          tooltip: 'Copy visible logs',
          icon: const Icon(Icons.copy_all_rounded),
          onPressed: _copy,
        ),
        IconButton(
          tooltip: 'Clear local logs',
          icon: const Icon(Icons.delete_outline_rounded),
          onPressed: _store.clear,
        ),
      ],
      body: AnimatedBuilder(
        animation: _store,
        builder: (context, _) {
          final entries = [
            for (final entry in _store.entries)
              if (!_remoteOnly || entry.isRemote) entry,
          ].reversed.toList(growable: false);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  t.spacing.md,
                  t.spacing.md,
                  t.spacing.md,
                  t.spacing.sm,
                ),
                child: Text(
                  'Local diagnostics from this app launch. Copy the visible '
                  'entries and paste them into a report.',
                  style: t.typography.bodyMedium.copyWith(
                    color: t.colors.textSecondary,
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: t.spacing.md),
                child: SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text('Remote')),
                    ButtonSegment(value: false, label: Text('All')),
                  ],
                  selected: {_remoteOnly},
                  onSelectionChanged: (selected) {
                    setState(() => _remoteOnly = selected.single);
                  },
                ),
              ),
              SizedBox(height: t.spacing.sm),
              Expanded(
                child: entries.isEmpty
                    ? _EmptyLogs(remoteOnly: _remoteOnly)
                    : ListView.separated(
                        padding: EdgeInsets.fromLTRB(
                          t.spacing.md,
                          t.spacing.sm,
                          t.spacing.md,
                          t.spacing.xl,
                        ),
                        itemCount: entries.length,
                        separatorBuilder: (_, _) => Divider(
                          color: t.colors.border,
                          height: t.spacing.md,
                        ),
                        itemBuilder: (context, index) => SelectableText(
                          entries[index].formatted,
                          style: t.typography.caption.copyWith(
                            color: _colorFor(entries[index], t),
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _copy() async {
    final text = _store.text(remoteOnly: _remoteOnly);
    if (text.isEmpty || !mounted) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_remoteOnly ? 'Remote logs copied' : 'Logs copied')),
    );
  }

  Color _colorFor(LocalLogEntry entry, AppTokens t) => switch (entry.level) {
    LogLevel.error => t.colors.danger,
    LogLevel.warning => t.colors.warning,
    LogLevel.debug => t.colors.textSecondary,
    LogLevel.info => t.colors.textPrimary,
  };
}

class _EmptyLogs extends StatelessWidget {
  const _EmptyLogs({required this.remoteOnly});

  final bool remoteOnly;

  @override
  Widget build(BuildContext context) => EmptyStateView(
    icon: Icons.article_outlined,
    title: remoteOnly ? 'No Remote logs yet' : 'No local logs yet',
    message: remoteOnly
        ? 'Open Remote or try a device action. Connected-playback activity '
              'will appear here automatically.'
        : 'Events from this app launch will appear here automatically.',
  );
}

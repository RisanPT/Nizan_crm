import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:nizan_crm/core/theme/crm_theme.dart';
import 'package:nizan_crm/core/error/errors.dart';
import 'package:nizan_crm/core/utils/file_saver.dart';
import 'package:nizan_crm/features/backup/services/backup_service.dart';

String _stamp() {
  final d = DateTime.now();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)}';
}

class BackupScreen extends HookConsumerWidget {
  const BackupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crm = context.crmColors;
    final async = ref.watch(backupTargetsProvider);
    // Which target is currently downloading ('__full__' or a department key).
    final busy = useState<String?>(null);

    Future<void> download({required String targetKey, required String filename, required Future<List<int>> Function() fetch}) async {
      if (busy.value != null) return;
      busy.value = targetKey;
      final messenger = ScaffoldMessenger.of(context);
      try {
        final bytes = await fetch();
        if (bytes.isEmpty) throw Exception('The backup came back empty. Please try again.');
        await saveFileBytes(filename, bytes, mime: 'application/json');
        messenger.showSnackBar(SnackBar(content: Text('Backup ready: $filename')));
      } catch (e) {
        messenger.showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e))));
      } finally {
        busy.value = null;
      }
    }

    return Scaffold(
      backgroundColor: crm.background,
      body: Column(children: [
        Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
          decoration: BoxDecoration(color: crm.surface, border: Border(bottom: BorderSide(color: crm.border))),
          child: Row(children: [
            Icon(Icons.cloud_download_outlined, color: crm.primary),
            const SizedBox(width: 10),
            Text('Backup Data', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: crm.primary)),
            const Spacer(),
            IconButton(onPressed: () => ref.invalidate(backupTargetsProvider), icon: const Icon(Icons.refresh)),
          ]),
        ),
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => AppErrorView(error: e, onRetry: () => ref.invalidate(backupTargetsProvider)),
            data: (t) => (t.departments.isEmpty && !t.full)
                ? Center(child: Text('You don’t have backup access.', style: TextStyle(color: crm.textSecondary)))
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    children: [
                      Text(
                        'Download your data as a JSON file. Each backup contains the records '
                        'for that area, and can be kept safely off-device.',
                        style: TextStyle(color: crm.textSecondary, fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      if (t.full) ...[
                        _card(
                          crm,
                          icon: Icons.dns_outlined,
                          title: 'Full Backup',
                          subtitle: 'Every collection in the database (IT / admin only)',
                          accent: crm.primary,
                          downloading: busy.value == '__full__',
                          disabled: busy.value != null && busy.value != '__full__',
                          onDownload: () => download(
                            targetKey: '__full__',
                            filename: 'full-backup-${_stamp()}.json',
                            fetch: () => ref.read(backupServiceProvider).downloadFull(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(children: [
                            Expanded(child: Divider(color: crm.border)),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              child: Text('BY DEPARTMENT',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1, color: crm.textSecondary)),
                            ),
                            Expanded(child: Divider(color: crm.border)),
                          ]),
                        ),
                      ],
                      for (final d in t.departments)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _card(
                            crm,
                            icon: Icons.folder_zip_outlined,
                            title: '${d.label} data',
                            subtitle: '${d.collections} collection${d.collections == 1 ? '' : 's'}',
                            accent: crm.textSecondary,
                            downloading: busy.value == d.key,
                            disabled: busy.value != null && busy.value != d.key,
                            onDownload: () => download(
                              targetKey: d.key,
                              filename: '${d.key}-backup-${_stamp()}.json',
                              fetch: () => ref.read(backupServiceProvider).downloadDepartment(d.key),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ),
      ]),
    );
  }

  Widget _card(
    CrmTheme crm, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color accent,
    required bool downloading,
    required bool disabled,
    required VoidCallback onDownload,
  }) =>
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: crm.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: crm.border),
        ),
        child: Row(children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: accent.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(11)),
            child: Icon(icon, color: accent, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(color: crm.textSecondary, fontSize: 12.5)),
            ]),
          ),
          const SizedBox(width: 10),
          FilledButton.icon(
            onPressed: (downloading || disabled) ? null : onDownload,
            icon: downloading
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.download, size: 18),
            label: Text(downloading ? 'Preparing…' : 'Download'),
          ),
        ]),
      );
}

import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/utils/extensions.dart';
import '../../data/export_service.dart';
import '../../data/import_service.dart';

/// Screen for importing and exporting household data.
class ImportExportScreen extends ConsumerStatefulWidget {
  final String householdId;

  const ImportExportScreen({super.key, required this.householdId});

  @override
  ConsumerState<ImportExportScreen> createState() => _ImportExportScreenState();
}

class _ImportExportScreenState extends ConsumerState<ImportExportScreen> {
  DateTime? _lastExport;
  bool _busy = false;
  double _importProgress = 0;
  String _importStatus = '';

  @override
  void initState() {
    super.initState();
    _loadLastExportDate();
  }

  Future<void> _loadLastExportDate() async {
    final date = await ExportService.getLastExportDate();
    if (mounted) setState(() => _lastExport = date);
  }

  Future<String?> _askPassphrase({required String title, required String hint}) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          obscureText: true,
          decoration: InputDecoration(hintText: hint),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: Text(context.l10n.commonOk),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _exportJson() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);

    // Ask for required passphrase.
    String? passphrase;
    while (passphrase == null || passphrase.isEmpty) {
      passphrase = await _askPassphrase(
        title: l10n.ieExportPassphrase,
        hint: l10n.ieExportPassphraseHint,
      );
      // null means the dialog was cancelled.
      if (passphrase == null) return;

      if (passphrase.isEmpty) {
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.ieExportPassphraseRequired)),
        );
        passphrase = null;
      }
    }

    setState(() => _busy = true);
    try {
      final service = ref.read(exportServiceProvider);
      final file = await service.exportAsJson(
        widget.householdId,
        passphrase: passphrase,
      );
      await service.shareFile(file);
      // Auto-delete export file after 5 minutes.
      unawaited(Future.delayed(const Duration(minutes: 5), () {
        file.deleteSync();
      }));
      await _loadLastExportDate();
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.ieExportSuccess)),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.ieExportFailed(e.toString()))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exportCsv() async {
    setState(() => _busy = true);
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final service = ref.read(exportServiceProvider);
      final file = await service.exportTasksCsv(widget.householdId);
      await service.shareFile(file);
      await _loadLastExportDate();
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.ieExportSuccess)),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.ieExportFailed(e.toString()))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importFromBackup() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);

    // Pick file — allow .json and .enc files.
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json', 'enc'],
    );

    if (result == null || result.files.single.path == null) return;

    final file = File(result.files.single.path!);
    final isEncrypted = file.path.endsWith('.enc');

    // If encrypted, ask for the passphrase before starting.
    String? passphrase;
    if (isEncrypted) {
      if (!mounted) return;
      passphrase = await _askPassphrase(
        title: l10n.ieImportPassphrase,
        hint: l10n.ieImportEncrypted,
      );
      if (passphrase == null) return; // cancelled
    }

    setState(() {
      _busy = true;
      _importProgress = 0;
      _importStatus = l10n.ieImportReading;
    });

    try {
      final service = ref.read(importServiceProvider);
      final data = await service.parseFile(file, passphrase: passphrase);

      // Validate
      final error = service.validate(data);
      if (error != null) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.ieImportInvalid(error))),
        );
        return;
      }

      // Confirm
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: Icon(
            Icons.file_download_outlined,
            size: 48,
            color: Theme.of(ctx).colorScheme.primary,
          ),
          title: Text(l10n.ieImportConfirmTitle),
          content: Text(l10n.ieImportConfirmMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(l10n.commonCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(l10n.ieImportButton),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      // Import
      final importResult = await service.importData(
        householdId: widget.householdId,
        data: data,
        onProgress: (progress, status) {
          if (mounted) {
            setState(() {
              _importProgress = progress;
              _importStatus = status;
            });
          }
        },
      );

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            l10n.ieImportSuccess(importResult.created, importResult.skipped),
          ),
        ),
      );

      // Show error details if any items failed.
      if (importResult.hasErrors && mounted) {
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(l10n.ieImportErrorsTitle),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.ieImportErrorsCount(importResult.errors.length)),
                  const SizedBox(height: 12),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: importResult.errors.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final err = importResult.errors[i];
                        return ListTile(
                          dense: true,
                          leading: Icon(Icons.warning_amber_rounded,
                              size: 20, color: Theme.of(ctx).colorScheme.error),
                          title: Text('${err.entityType}: ${err.entityName}'),
                          subtitle: Text(err.message,
                              maxLines: 2, overflow: TextOverflow.ellipsis),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(l10n.commonOk),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.ieImportFailed(e.toString()))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _importProgress = 0;
          _importStatus = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.ieTitle),
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── Export section ──
              Text(
                context.l10n.ieExportSection,
                style: context.textTheme.titleSmall?.copyWith(
                  color: context.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),

              // Export as JSON
              _ActionCard(
                icon: Icons.data_object_rounded,
                title: context.l10n.ieExportJson,
                subtitle: context.l10n.ieExportJsonDesc,
                onTap: _busy ? null : _exportJson,
              ),

              const SizedBox(height: 8),

              // Export as CSV
              _ActionCard(
                icon: Icons.table_chart_outlined,
                title: context.l10n.ieExportCsv,
                subtitle: context.l10n.ieExportCsvDesc,
                onTap: _busy ? null : _exportCsv,
              ),

              if (_lastExport != null) ...[
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    context.l10n.ieLastExport(
                      DateFormat.yMMMd().add_jm().format(_lastExport!),
                    ),
                    style: context.textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],

              const SizedBox(height: 32),

              // ── Import section ──
              Text(
                context.l10n.ieImportSection,
                style: context.textTheme.titleSmall?.copyWith(
                  color: context.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 12),

              // Import from backup
              _ActionCard(
                icon: Icons.file_upload_outlined,
                title: context.l10n.ieImportButton,
                subtitle: context.l10n.ieImportDesc,
                onTap: _busy ? null : _importFromBackup,
              ),

              const SizedBox(height: 24),

              // Info note
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  context.l10n.ieInfoNote,
                  style: context.textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),

          // Progress overlay
          if (_busy && _importStatus.isNotEmpty)
            Container(
              color: Colors.black54,
              child: Center(
                child: Card(
                  margin: const EdgeInsets.all(32),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          value: _importProgress > 0 ? _importProgress : null,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _importStatus,
                          style: context.textTheme.bodyMedium,
                        ),
                        if (_importProgress > 0) ...[
                          const SizedBox(height: 8),
                          Text(
                            '${(_importProgress * 100).toStringAsFixed(0)}%',
                            style: context.textTheme.titleMedium,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Reusable card for export/import actions.
class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title, style: Theme.of(context).textTheme.titleMedium),
        subtitle:
            Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }
}

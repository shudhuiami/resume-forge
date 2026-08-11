import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/resume_repository.dart';
import '../models/resume.dart';
import '../state/app_providers.dart';
import '../templates/registry.dart';
import '../theme/tokens.dart';
import 'editor_screen.dart';
import 'gallery_screen.dart';

/// Home: everything the user has saved.
class ResumeListScreen extends ConsumerWidget {
  const ResumeListScreen({super.key});

  Future<void> _createNew(BuildContext context, WidgetRef ref) async {
    final templateId = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => GalleryScreen(
          selectedId: defaultTemplate.id,
          title: 'Start with a design',
          onSelected: (id) => Navigator.of(context).pop(id),
        ),
      ),
    );
    if (templateId == null || !context.mounted) return;

    final doc = newResumeDocument(templateId: templateId);
    await ref.read(repositoryProvider).save(doc);
    if (!context.mounted) return;

    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => EditorScreen(document: doc)));
  }

  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    ResumeDocument doc,
  ) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => EditorScreen(document: doc)));
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    ResumeDocument doc,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this resume?'),
        content: Text(
          '"${doc.displayTitle}" will be permanently removed from this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(repositoryProvider).delete(doc.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resumes = ref.watch(resumeListProvider);
    final tokens = context.tokens;

    return Scaffold(
      appBar: AppBar(title: const Text('ResumeForge')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createNew(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New resume'),
      ),
      body: SafeArea(
        child: resumes.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) =>
              _ErrorState(onRetry: () => ref.invalidate(resumeListProvider)),
          data: (docs) {
            if (docs.isEmpty) {
              return _EmptyState(onCreate: () => _createNew(context, ref));
            }
            return ListView.builder(
              padding: EdgeInsets.fromLTRB(
                tokens.spaceLg,
                tokens.spaceSm,
                tokens.spaceLg,
                tokens.spaceXxl * 2.5,
              ),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final doc = docs[index];
                return _ResumeTile(
                  doc: doc,
                  onTap: () => _open(context, ref, doc),
                  onDelete: () => _confirmDelete(context, ref, doc),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _ResumeTile extends StatelessWidget {
  const _ResumeTile({
    required this.doc,
    required this.onTap,
    required this.onDelete,
  });

  final ResumeDocument doc;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    final template = templateById(doc.templateId);

    return Card(
      margin: EdgeInsets.only(bottom: tokens.spaceMd),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(
          horizontal: tokens.spaceLg,
          vertical: tokens.spaceSm,
        ),
        onTap: onTap,
        title: Text(
          doc.displayTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '${template.name} · edited ${_relative(doc.updatedAt)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        trailing: IconButton(
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline),
          tooltip: 'Delete ${doc.displayTitle}',
        ),
      ),
    );
  }

  static String _relative(DateTime when) {
    final diff = DateTime.now().difference(when);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 30) return '${diff.inDays}d ago';
    return '${when.year}-${when.month.toString().padLeft(2, '0')}';
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.description_outlined,
              size: 56,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text('No resumes yet', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Pick a design, fill in your details, and export a PDF. '
              'Everything stays on this device.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: const Text('Create your first resume'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 12),
            Text(
              'Could not load your saved resumes',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}

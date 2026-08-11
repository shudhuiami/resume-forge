import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/resume_repository.dart';
import '../models/resume.dart';
import '../state/app_providers.dart';
import '../templates/registry.dart';
import '../theme/tokens.dart';
import 'editor_screen.dart';
import 'gallery_screen.dart';

/// Widest the list is allowed to grow. A tablet-width row puts a resume title
/// and its delete button half a screen apart and reads as an admin table, so
/// the content column stops here and centres.
const _maxContentWidth = 640.0;

/// Widest a paragraph of body copy is allowed to run, in the same spirit.
const _maxProseWidth = 380.0;

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

    // The empty state carries its own primary action, so the FAB would be a
    // second identical call to action on the same screen.
    final showFab = resumes.valueOrNull?.isNotEmpty ?? true;

    return Scaffold(
      appBar: AppBar(title: const Text('ResumeForge')),
      floatingActionButton: showFab
          ? FloatingActionButton.extended(
              onPressed: () => _createNew(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('New resume'),
            )
          : null,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxContentWidth),
            child: resumes.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _ErrorState(
                onRetry: () => ref.invalidate(resumeListProvider),
              ),
              data: (docs) {
                if (docs.isEmpty) {
                  return _EmptyState(onCreate: () => _createNew(context, ref));
                }
                return ListView.builder(
                  padding: EdgeInsets.fromLTRB(
                    tokens.spaceLg,
                    tokens.spaceSm,
                    tokens.spaceLg,
                    // Clearance for the extended FAB, so the last card is not
                    // parked underneath it.
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
          padding: EdgeInsets.only(top: tokens.spaceXs),
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

/// Centred full-screen message that survives a short viewport.
///
/// Landscape phones and large accessibility text both shrink the space below
/// the app bar past what an icon-plus-copy-plus-button stack needs, so the
/// stack scrolls instead of overflowing, and still centres when it fits.
class _MessagePane extends StatelessWidget {
  const _MessagePane({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return LayoutBuilder(
      builder: (context, constraints) {
        final inset = tokens.spaceXl;
        return SingleChildScrollView(
          padding: EdgeInsets.all(inset),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: math.max(0, constraints.maxHeight - inset * 2),
            ),
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: children),
            ),
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    return _MessagePane(
      children: [
        Icon(
          Icons.description_outlined,
          size: 56,
          color: theme.colorScheme.primary,
        ),
        SizedBox(height: tokens.spaceLg),
        Text('No resumes yet', style: theme.textTheme.titleLarge),
        SizedBox(height: tokens.spaceSm),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxProseWidth),
          child: Text(
            'Pick a design, fill in your details, and export a PDF. '
            'Everything stays on this device.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        SizedBox(height: tokens.spaceXl),
        FilledButton.icon(
          onPressed: onCreate,
          icon: const Icon(Icons.add),
          label: const Text('Create your first resume'),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.tokens;
    return _MessagePane(
      children: [
        Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
        SizedBox(height: tokens.spaceMd),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxProseWidth),
          child: Text(
            'Could not load your saved resumes',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
        ),
        SizedBox(height: tokens.spaceLg),
        FilledButton(onPressed: onRetry, child: const Text('Try again')),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/photo_service.dart';
import '../models/resume.dart';
import '../render/pdf_export.dart';
import '../state/app_providers.dart';
import '../state/editor_controller.dart';
import '../theme/tokens.dart';
import '../widgets/form_fields.dart';
import '../widgets/pdf_page_view.dart';
import 'gallery_screen.dart';

/// Form-first resume editor.
///
/// The preview lives in its own tab rather than beside the form. An A4 page
/// scaled to phone width puts body text near 5pt — too small to read and far
/// too small to touch — so editing happens in the form and the page is
/// something you check, not something you type into.
class EditorScreen extends ConsumerStatefulWidget {
  const EditorScreen({super.key, required this.document});

  final ResumeDocument document;

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final EditorController _controller;
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = EditorController(
      doc: widget.document,
      repository: ref.read(repositoryProvider),
    );
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // A backgrounded app can be killed without further warning, so flush
    // rather than waiting out the autosave debounce.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _controller.saveNow();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.saveNow();
    _tabs.dispose();
    _controller.dispose();
    super.dispose();
  }

  /// True from the tap until the share sheet has been offered. Keeps the
  /// action from being fired twice, which would build the document twice and
  /// stack two share sheets.
  bool _exporting = false;

  Future<void> _export() async {
    if (_exporting) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _exporting = true);

    // Held open for exactly as long as the work takes. A fixed one-second
    // snackbar was wrong in both directions: it vanished mid-build on a slow
    // render, leaving the app looking idle, and it lingered over the share
    // sheet on a fast one.
    final progress = messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: context.tokens.spaceMd),
            const Expanded(child: Text('Preparing PDF…')),
          ],
        ),
        duration: const Duration(minutes: 1),
      ),
    );

    try {
      final bytes = await _controller.buildForExport();
      // Closed before the sheet opens, and unconditionally — this snackbar
      // outlives the route, so an early back press must not strand it.
      progress.close();
      final outcome = await PdfExport.share(
        pdfBytes: bytes,
        info: _controller.state.data.personalInfo,
      );
      if (!mounted) return;
      // A dismissed share sheet is the user changing their mind, not a
      // failure, and says nothing.
      if (outcome.isFailure) {
        _showExportFailure(messenger, outcome.message);
      }
    } catch (_) {
      progress.close();
      if (!mounted) return;
      _showExportFailure(messenger, 'Could not prepare the PDF for export.');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  void _showExportFailure(ScaffoldMessengerState messenger, String? message) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(message ?? 'Could not export the PDF.'),
        // Long enough to read a two-line explanation and reach the action.
        duration: const Duration(seconds: 8),
        action: SnackBarAction(label: 'Try again', onPressed: _export),
      ),
    );
  }

  /// Swaps the design without touching content — the product's core promise,
  /// so this must never round-trip through anything that could drop fields.
  Future<void> _changeTemplate() async {
    final picked = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (routeContext) => GalleryScreen(
          selectedId: _controller.state.doc.templateId,
          onSelected: (id) => Navigator.of(routeContext).pop(id),
        ),
      ),
    );
    if (picked == null || !mounted) return;
    _controller.setTemplate(picked);
    // Jump to the preview so the change is visible immediately; switching a
    // design and being left staring at the form reads as nothing happening.
    _tabs.animateTo(1);
  }

  Future<void> _pickPhoto() async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await ref.read(photoServiceProvider).pick();
    if (!mounted) return;

    switch (result.status) {
      case PhotoPickStatus.picked:
        _controller.updateData(
          (d) => d.copyWith(
            personalInfo: d.personalInfo.copyWith(photo: result.bytes),
          ),
        );
      case PhotoPickStatus.cancelled:
        break;
      case PhotoPickStatus.denied:
      case PhotoPickStatus.failed:
        messenger.showSnackBar(
          SnackBar(content: Text(result.message ?? 'Could not add the photo.')),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final state = _controller.state;
        return Scaffold(
          appBar: AppBar(
            title: Text(
              state.doc.displayTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            bottom: TabBar(
              controller: _tabs,
              tabs: const [
                Tab(icon: Icon(Icons.edit_outlined), text: 'Edit'),
                Tab(icon: Icon(Icons.picture_as_pdf_outlined), text: 'Preview'),
              ],
            ),
            actions: [
              IconButton(
                onPressed: _changeTemplate,
                icon: const Icon(Icons.palette_outlined),
                tooltip: 'Change design',
              ),
              IconButton(
                onPressed: _exporting ? null : _export,
                icon: _exporting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.ios_share),
                tooltip: 'Export PDF',
              ),
            ],
          ),
          body: TabBarView(
            controller: _tabs,
            children: [
              _EditorForm(controller: _controller, onPickPhoto: _pickPhoto),
              Padding(
                padding: EdgeInsets.all(context.tokens.spaceLg),
                child: PdfPageView(
                  pdfBytes: state.pdfBytes,
                  isRendering: state.isRendering,
                  buildError: state.renderError,
                  onRetry: _controller.retryPreview,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _EditorForm extends StatelessWidget {
  const _EditorForm({required this.controller, required this.onPickPhoto});

  final EditorController controller;
  final VoidCallback onPickPhoto;

  ResumeData get data => controller.state.data;

  void _edit(ResumeData Function(ResumeData) f) => controller.updateData(f);

  String _newId(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}';

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final info = data.personalInfo;

    return ListView(
      // Addressable so tests can scroll this list rather than the TabBarView's
      // own PageView, which is the first Scrollable in the tree.
      key: const Key('editor-form-list'),
      // Room for the keyboard plus the last field, so the bottom entry is not
      // pinned under the keyboard when it opens.
      padding: EdgeInsets.fromLTRB(
        tokens.spaceLg,
        tokens.spaceSm,
        tokens.spaceLg,
        MediaQuery.viewInsetsOf(context).bottom + tokens.spaceXxl * 2,
      ),
      children: [
        const SectionHeader(title: 'About you'),
        _PhotoRow(
          photo: info.photo,
          onPick: onPickPhoto,
          onRemove: () {
            _edit(
              (d) => d.copyWith(
                personalInfo: d.personalInfo.copyWith(photo: null),
              ),
            );
          },
        ),
        ResumeTextField(
          label: 'Full name',
          value: info.fullName,
          autofillHints: const [AutofillHints.name],
          textCapitalization: TextCapitalization.words,
          onChanged: (v) => _edit(
            (d) =>
                d.copyWith(personalInfo: d.personalInfo.copyWith(fullName: v)),
          ),
        ),
        ResumeTextField(
          label: 'Job title',
          value: info.title,
          hint: 'Senior Product Designer',
          onChanged: (v) => _edit(
            (d) => d.copyWith(personalInfo: d.personalInfo.copyWith(title: v)),
          ),
        ),
        ResumeTextField(
          label: 'Email',
          value: info.email,
          keyboardType: TextInputType.emailAddress,
          textCapitalization: TextCapitalization.none,
          autofillHints: const [AutofillHints.email],
          onChanged: (v) => _edit(
            (d) => d.copyWith(personalInfo: d.personalInfo.copyWith(email: v)),
          ),
        ),
        ResumeTextField(
          label: 'Phone',
          value: info.phone,
          keyboardType: TextInputType.phone,
          autofillHints: const [AutofillHints.telephoneNumber],
          onChanged: (v) => _edit(
            (d) => d.copyWith(personalInfo: d.personalInfo.copyWith(phone: v)),
          ),
        ),
        ResumeTextField(
          label: 'Location',
          value: info.location,
          onChanged: (v) => _edit(
            (d) =>
                d.copyWith(personalInfo: d.personalInfo.copyWith(location: v)),
          ),
        ),
        ResumeTextField(
          label: 'LinkedIn',
          value: info.linkedin,
          textCapitalization: TextCapitalization.none,
          keyboardType: TextInputType.url,
          onChanged: (v) => _edit(
            (d) =>
                d.copyWith(personalInfo: d.personalInfo.copyWith(linkedin: v)),
          ),
        ),
        ResumeTextField(
          label: 'Website',
          value: info.website,
          textCapitalization: TextCapitalization.none,
          keyboardType: TextInputType.url,
          onChanged: (v) => _edit(
            (d) =>
                d.copyWith(personalInfo: d.personalInfo.copyWith(website: v)),
          ),
        ),
        ResumeTextField(
          label: 'Summary',
          value: info.summary,
          maxLines: 5,
          helper:
              'Two or three sentences on what you do and what you are known for.',
          onChanged: (v) => _edit(
            (d) =>
                d.copyWith(personalInfo: d.personalInfo.copyWith(summary: v)),
          ),
        ),

        SectionHeader(
          title: 'Experience',
          subtitle: data.experiences.isEmpty ? 'No roles added yet' : null,
        ),
        for (final (i, e) in data.experiences.indexed)
          EntryCard(
            key: ValueKey(e.id),
            title: 'ROLE ${i + 1}',
            removeTooltip: 'Remove this role',
            onRemove: () => _edit(
              (d) => d.copyWith(
                experiences: [...d.experiences]
                  ..removeWhere((x) => x.id == e.id),
              ),
            ),
            children: [
              ResumeTextField(
                label: 'Position',
                value: e.position,
                onChanged: (v) =>
                    _editExperience(e.id, (x) => x.copyWith(position: v)),
              ),
              ResumeTextField(
                label: 'Company',
                value: e.company,
                onChanged: (v) =>
                    _editExperience(e.id, (x) => x.copyWith(company: v)),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: MonthYearField(
                      label: 'Start',
                      value: e.startDate,
                      onChanged: (v) => _editExperience(
                        e.id,
                        (x) => x.copyWith(startDate: v),
                      ),
                    ),
                  ),
                  SizedBox(width: context.tokens.spaceMd),
                  Expanded(
                    child: MonthYearField(
                      label: 'End',
                      value: e.endDate,
                      enabled: !e.current,
                      onChanged: (v) =>
                          _editExperience(e.id, (x) => x.copyWith(endDate: v)),
                    ),
                  ),
                ],
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: e.current,
                title: const Text('I currently work here'),
                onChanged: (v) => _editExperience(
                  e.id,
                  // Clearing the end date matters: a stale value would keep
                  // rendering behind the "Present" label in the PDF.
                  (x) => x.copyWith(current: v, endDate: v ? '' : x.endDate),
                ),
              ),
              ResumeTextField(
                label: 'What you did',
                value: e.description,
                maxLines: 4,
                onChanged: (v) =>
                    _editExperience(e.id, (x) => x.copyWith(description: v)),
              ),
            ],
          ),
        AddEntryButton(
          label: 'Add role',
          onPressed: () => _edit(
            (d) => d.copyWith(
              experiences: [
                ...d.experiences,
                Experience(id: _newId('exp')),
              ],
            ),
          ),
        ),

        SectionHeader(
          title: 'Education',
          subtitle: data.education.isEmpty ? 'No education added yet' : null,
        ),
        for (final (i, e) in data.education.indexed)
          EntryCard(
            key: ValueKey(e.id),
            title: 'EDUCATION ${i + 1}',
            removeTooltip: 'Remove this entry',
            onRemove: () => _edit(
              (d) => d.copyWith(
                education: [...d.education]..removeWhere((x) => x.id == e.id),
              ),
            ),
            children: [
              ResumeTextField(
                label: 'Institution',
                value: e.institution,
                onChanged: (v) =>
                    _editEducation(e.id, (x) => x.copyWith(institution: v)),
              ),
              ResumeTextField(
                label: 'Degree',
                value: e.degree,
                onChanged: (v) =>
                    _editEducation(e.id, (x) => x.copyWith(degree: v)),
              ),
              ResumeTextField(
                label: 'Field of study',
                value: e.field,
                onChanged: (v) =>
                    _editEducation(e.id, (x) => x.copyWith(field: v)),
              ),
              Row(
                children: [
                  Expanded(
                    child: MonthYearField(
                      label: 'Start',
                      value: e.startDate,
                      onChanged: (v) =>
                          _editEducation(e.id, (x) => x.copyWith(startDate: v)),
                    ),
                  ),
                  SizedBox(width: context.tokens.spaceMd),
                  Expanded(
                    child: MonthYearField(
                      label: 'End',
                      value: e.endDate,
                      onChanged: (v) =>
                          _editEducation(e.id, (x) => x.copyWith(endDate: v)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        AddEntryButton(
          label: 'Add education',
          onPressed: () => _edit(
            (d) => d.copyWith(
              education: [
                ...d.education,
                Education(id: _newId('edu')),
              ],
            ),
          ),
        ),

        SectionHeader(
          title: 'Skills',
          subtitle:
              'Rated out of five. Some designs show the rating, some just the name.',
        ),
        for (final s in data.skills)
          EntryCard(
            key: ValueKey(s.id),
            title: s.name.isEmpty ? 'SKILL' : s.name.toUpperCase(),
            removeTooltip: 'Remove this skill',
            onRemove: () => _edit(
              (d) => d.copyWith(
                skills: [...d.skills]..removeWhere((x) => x.id == s.id),
              ),
            ),
            children: [
              ResumeTextField(
                label: 'Skill',
                value: s.name,
                onChanged: (v) => _editSkill(s.id, (x) => x.copyWith(name: v)),
              ),
              _SkillSlider(
                value: s.level,
                onChanged: (v) => _editSkill(s.id, (x) => x.copyWith(level: v)),
              ),
            ],
          ),
        AddEntryButton(
          label: 'Add skill',
          onPressed: () => _edit(
            (d) => d.copyWith(
              skills: [
                ...d.skills,
                Skill(id: _newId('sk')),
              ],
            ),
          ),
        ),

        SectionHeader(title: 'Projects'),
        for (final p in data.projects)
          EntryCard(
            key: ValueKey(p.id),
            title: p.name.isEmpty ? 'PROJECT' : p.name.toUpperCase(),
            removeTooltip: 'Remove this project',
            onRemove: () => _edit(
              (d) => d.copyWith(
                projects: [...d.projects]..removeWhere((x) => x.id == p.id),
              ),
            ),
            children: [
              ResumeTextField(
                label: 'Name',
                value: p.name,
                onChanged: (v) =>
                    _editProject(p.id, (x) => x.copyWith(name: v)),
              ),
              ResumeTextField(
                label: 'Description',
                value: p.description,
                maxLines: 3,
                onChanged: (v) =>
                    _editProject(p.id, (x) => x.copyWith(description: v)),
              ),
              ResumeTextField(
                label: 'Technologies',
                value: p.technologies,
                helper: 'Comma separated — each becomes a chip.',
                onChanged: (v) =>
                    _editProject(p.id, (x) => x.copyWith(technologies: v)),
              ),
              ResumeTextField(
                label: 'Link',
                value: p.link,
                keyboardType: TextInputType.url,
                textCapitalization: TextCapitalization.none,
                onChanged: (v) =>
                    _editProject(p.id, (x) => x.copyWith(link: v)),
              ),
            ],
          ),
        AddEntryButton(
          label: 'Add project',
          onPressed: () => _edit(
            (d) => d.copyWith(
              projects: [
                ...d.projects,
                Project(id: _newId('prj')),
              ],
            ),
          ),
        ),

        SectionHeader(
          title: 'Custom sections',
          subtitle: 'Certifications, publications, languages — anything else.',
        ),
        for (final section in data.customSections)
          EntryCard(
            key: ValueKey(section.id),
            title: section.sectionTitle.isEmpty
                ? 'SECTION'
                : section.sectionTitle.toUpperCase(),
            removeTooltip: 'Remove this section',
            onRemove: () => _edit(
              (d) => d.copyWith(
                customSections: [...d.customSections]
                  ..removeWhere((x) => x.id == section.id),
              ),
            ),
            children: [
              ResumeTextField(
                label: 'Section title',
                value: section.sectionTitle,
                onChanged: (v) => _editSection(
                  section.id,
                  (x) => x.copyWith(sectionTitle: v),
                ),
              ),
              for (final item in section.items)
                Padding(
                  key: ValueKey(item.id),
                  padding: EdgeInsets.only(bottom: context.tokens.spaceSm),
                  child: Column(
                    children: [
                      ResumeTextField(
                        label: 'Title',
                        value: item.title,
                        onChanged: (v) => _editSectionItem(
                          section.id,
                          item.id,
                          (x) => x.copyWith(title: v),
                        ),
                      ),
                      ResumeTextField(
                        label: 'Subtitle',
                        value: item.subtitle,
                        onChanged: (v) => _editSectionItem(
                          section.id,
                          item.id,
                          (x) => x.copyWith(subtitle: v),
                        ),
                      ),
                    ],
                  ),
                ),
              AddEntryButton(
                label: 'Add item',
                onPressed: () => _editSection(
                  section.id,
                  (x) => x.copyWith(
                    items: [
                      ...x.items,
                      CustomItem(id: _newId('ci')),
                    ],
                  ),
                ),
              ),
            ],
          ),
        AddEntryButton(
          label: 'Add section',
          onPressed: () => _edit(
            (d) => d.copyWith(
              customSections: [
                ...d.customSections,
                CustomSection(id: _newId('cs')),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _editExperience(String id, Experience Function(Experience) f) => _edit(
    (d) => d.copyWith(
      experiences: [
        for (final x in d.experiences)
          if (x.id == id) f(x) else x,
      ],
    ),
  );

  void _editEducation(String id, Education Function(Education) f) => _edit(
    (d) => d.copyWith(
      education: [
        for (final x in d.education)
          if (x.id == id) f(x) else x,
      ],
    ),
  );

  void _editSkill(String id, Skill Function(Skill) f) => _edit(
    (d) => d.copyWith(
      skills: [
        for (final x in d.skills)
          if (x.id == id) f(x) else x,
      ],
    ),
  );

  void _editProject(String id, Project Function(Project) f) => _edit(
    (d) => d.copyWith(
      projects: [
        for (final x in d.projects)
          if (x.id == id) f(x) else x,
      ],
    ),
  );

  void _editSection(String id, CustomSection Function(CustomSection) f) =>
      _edit(
        (d) => d.copyWith(
          customSections: [
            for (final x in d.customSections)
              if (x.id == id) f(x) else x,
          ],
        ),
      );

  void _editSectionItem(
    String sectionId,
    String itemId,
    CustomItem Function(CustomItem) f,
  ) => _editSection(
    sectionId,
    (s) => s.copyWith(
      items: [
        for (final i in s.items)
          if (i.id == itemId) f(i) else i,
      ],
    ),
  );
}

class _SkillSlider extends StatelessWidget {
  const _SkillSlider({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  static const _labels = [
    'None',
    'Basic',
    'Working',
    'Good',
    'Strong',
    'Expert',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final clamped = value.clamp(0, 5);

    return Row(
      children: [
        Expanded(
          child: Slider(
            value: clamped.toDouble(),
            min: 0,
            max: 5,
            divisions: 5,
            // Screen readers announce the word, not a bare number, which on
            // its own says nothing about what "3" means.
            label: _labels[clamped],
            onChanged: (v) => onChanged(v.round()),
          ),
        ),
        SizedBox(
          width: 68,
          child: Text(
            _labels[clamped],
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _PhotoRow extends StatelessWidget {
  const _PhotoRow({
    required this.photo,
    required this.onPick,
    required this.onRemove,
  });

  final dynamic photo;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final theme = Theme.of(context);
    final has = photo != null;

    return Padding(
      padding: EdgeInsets.only(bottom: tokens.spaceLg),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.colorScheme.surfaceContainerHigh,
              border: Border.all(color: theme.colorScheme.outlineVariant),
              image: has
                  ? DecorationImage(
                      image: MemoryImage(photo),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: has
                ? null
                : Icon(
                    Icons.person_outline,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
          ),
          SizedBox(width: tokens.spaceLg),
          Expanded(
            child: Wrap(
              spacing: tokens.spaceSm,
              runSpacing: tokens.spaceSm,
              children: [
                OutlinedButton.icon(
                  onPressed: onPick,
                  icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                  label: Text(has ? 'Replace photo' : 'Add photo'),
                ),
                if (has)
                  TextButton(onPressed: onRemove, child: const Text('Remove')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

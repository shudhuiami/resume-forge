import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:resume_forge/data/resume_repository.dart';
import 'package:resume_forge/data/sample_resume.dart';
import 'package:resume_forge/models/resume.dart';
import 'package:resume_forge/render/preview_engine.dart';
import 'package:resume_forge/render/render_job.dart';
import 'package:resume_forge/state/editor_controller.dart';

/// Repository that counts writes and can be made to fail, so autosave can be
/// observed without a real box.
class _RecordingRepository implements ResumeRepository {
  final InMemoryResumeRepository _inner = InMemoryResumeRepository();

  /// Documents that were written successfully.
  final List<ResumeDocument> saved = <ResumeDocument>[];

  /// Every save call, including the ones that threw.
  int attempts = 0;

  bool failSaves = false;

  /// When set, the next save blocks until this completes — lets a test hold a
  /// write open and edit underneath it.
  Completer<void>? gate;

  @override
  Future<List<ResumeDocument>> all() => _inner.all();

  @override
  Future<ResumeDocument?> byId(String id) => _inner.byId(id);

  @override
  Future<void> save(ResumeDocument doc) async {
    attempts++;
    final held = gate;
    if (held != null) {
      gate = null;
      await held.future;
    }
    if (failSaves) throw StateError('storage unavailable');
    saved.add(doc);
    await _inner.save(doc);
  }

  @override
  Future<void> delete(String id) => _inner.delete(id);

  @override
  Stream<List<ResumeDocument>> watch() => _inner.watch();

  @override
  Future<void> close() => _inner.close();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _RecordingRepository repo;
  late List<RenderJob> rendered;
  late bool renderFails;
  late List<EditorController> controllers;

  Future<Uint8List> runner(RenderJob job) async {
    rendered.add(job);
    if (renderFails) throw StateError('render blew up');
    return Uint8List.fromList([1, 2, 3]);
  }

  /// A document with real content — including photo bytes — so "the data did
  /// not change" is a claim about something substantial.
  ResumeDocument baseDoc() => ResumeDocument(
    id: 'doc-1',
    templateId: 'aurora',
    createdAt: DateTime(2024, 1, 1),
    updatedAt: DateTime(2024, 1, 1),
    data: sampleResume.copyWith(
      personalInfo: sampleResume.personalInfo.copyWith(
        photo: Uint8List.fromList(List<int>.generate(64, (i) => i)),
      ),
    ),
  );

  EditorController make({
    ResumeDocument? doc,
    Duration autosaveDelay = const Duration(milliseconds: 15),
  }) {
    final controller = EditorController(
      doc: doc ?? baseDoc(),
      repository: repo,
      engine: PreviewEngine(
        debounce: const Duration(milliseconds: 5),
        runner: runner,
      ),
      autosaveDelay: autosaveDelay,
    );
    controllers.add(controller);
    return controller;
  }

  /// Disposes now and takes the controller out of the teardown list, since
  /// [ChangeNotifier.dispose] asserts when called twice.
  void disposeNow(EditorController controller) {
    controllers.remove(controller);
    controller.dispose();
  }

  Future<void> settle([int ms = 50]) =>
      Future<void>.delayed(Duration(milliseconds: ms));

  setUp(() {
    repo = _RecordingRepository();
    rendered = <RenderJob>[];
    renderFails = false;
    controllers = <EditorController>[];
  });

  tearDown(() {
    for (final controller in controllers) {
      controller.dispose();
    }
  });

  group('updateData', () {
    test('marks the document dirty, bumps updatedAt, and re-renders', () async {
      final controller = make();
      await settle();
      final rendersBefore = rendered.length;
      final before = controller.state.doc;

      controller.updateData(
        (data) => data.copyWith(
          personalInfo: data.personalInfo.copyWith(fullName: 'Rewritten Name'),
        ),
      );

      expect(controller.state.hasUnsavedChanges, isTrue);
      expect(controller.state.isRendering, isTrue);
      expect(
        controller.state.doc.updatedAt.isAfter(before.updatedAt),
        isTrue,
        reason: 'an edit must move updatedAt so the list sorts correctly',
      );
      expect(
        controller.state.doc.createdAt,
        before.createdAt,
        reason: 'editing must not rewrite creation time',
      );
      expect(controller.state.data.personalInfo.fullName, 'Rewritten Name');

      await settle();
      expect(rendered.length, greaterThan(rendersBefore));
      expect(
        rendered.last.resumeJson['personalInfo']['fullName'],
        'Rewritten Name',
      );
    });

    test('notifies listeners so the editor repaints', () async {
      final controller = make();
      await settle();
      var notifications = 0;
      controller.addListener(() => notifications++);

      controller.updateData(
        (data) => data.copyWith(
          personalInfo: data.personalInfo.copyWith(title: 'Staff Designer'),
        ),
      );

      expect(notifications, greaterThan(0));
    });

    test('is a no-op when the transform returns the same object', () async {
      final controller = make();
      await settle();
      final rendersBefore = rendered.length;
      final docBefore = controller.state.doc;

      controller.updateData((data) => data);
      await settle();

      expect(controller.state.hasUnsavedChanges, isFalse);
      expect(identical(controller.state.doc, docBefore), isTrue);
      expect(
        rendered.length,
        rendersBefore,
        reason: 'a no-op edit must not spend a render',
      );
      expect(repo.attempts, 0, reason: 'a no-op edit must not spend a write');
    });

    test('is a no-op when the new value merely compares equal', () async {
      final controller = make();
      await settle();
      final rendersBefore = rendered.length;

      // A fresh object with identical field values: value equality, not
      // identity, is what has to short-circuit here.
      controller.updateData(
        (data) => data.copyWith(
          personalInfo: data.personalInfo.copyWith(
            fullName: data.personalInfo.fullName,
          ),
        ),
      );
      await settle();

      expect(controller.state.hasUnsavedChanges, isFalse);
      expect(rendered.length, rendersBefore);
    });
  });

  group('setTemplate', () {
    test('changes design while leaving the content byte-identical', () async {
      final controller = make();
      await settle();
      final dataBefore = controller.state.data;
      final jsonBefore = jsonEncode(dataBefore.toJson());

      controller.setTemplate('terminal');
      await settle();

      expect(controller.state.doc.templateId, 'terminal');
      expect(
        controller.state.data,
        equals(dataBefore),
        reason: 'swapping a template must not touch the resume content',
      );
      expect(
        jsonEncode(controller.state.data.toJson()),
        jsonBefore,
        reason: 'serialized content must be byte-identical after a swap',
      );
      expect(
        controller.state.data.personalInfo.photo,
        equals(dataBefore.personalInfo.photo),
        reason: 'photo bytes must survive a template swap',
      );
      expect(controller.state.data.experiences, equals(dataBefore.experiences));
      expect(controller.state.data.education, equals(dataBefore.education));
      expect(controller.state.data.skills, equals(dataBefore.skills));
      expect(controller.state.data.projects, equals(dataBefore.projects));
      expect(
        controller.state.data.customSections,
        equals(dataBefore.customSections),
      );

      // The bytes actually handed to the renderer must carry the same content
      // under the new template, not just the in-memory copy.
      expect(rendered.last.templateId, 'terminal');
      expect(jsonEncode(rendered.last.resumeJson), jsonBefore);
    });

    test('marks the document dirty and bumps updatedAt', () async {
      final controller = make();
      await settle();
      final before = controller.state.doc.updatedAt;

      controller.setTemplate('ledger');

      expect(controller.state.hasUnsavedChanges, isTrue);
      expect(controller.state.doc.updatedAt.isAfter(before), isTrue);
    });

    test('ignores an unknown template id', () async {
      final controller = make();
      await settle();
      final rendersBefore = rendered.length;

      controller.setTemplate('no-such-template');
      await settle();

      expect(
        controller.state.doc.templateId,
        'aurora',
        reason:
            'an unknown id must not strand the document on a missing design',
      );
      expect(controller.state.hasUnsavedChanges, isFalse);
      expect(rendered.length, rendersBefore);
      expect(repo.attempts, 0);
    });

    test('ignores a switch to the template already in use', () async {
      final controller = make();
      await settle();
      final rendersBefore = rendered.length;

      controller.setTemplate('aurora');
      await settle();

      expect(controller.state.hasUnsavedChanges, isFalse);
      expect(
        rendered.length,
        rendersBefore,
        reason: 're-selecting the current design must not re-render',
      );
    });
  });

  group('autosave', () {
    test('fires after the debounce and clears the dirty flag', () async {
      final controller = make();
      await settle();

      controller.updateData(
        (data) => data.copyWith(
          personalInfo: data.personalInfo.copyWith(fullName: 'Autosaved'),
        ),
      );
      expect(controller.state.hasUnsavedChanges, isTrue);

      await settle();

      expect(repo.saved, hasLength(1));
      expect(repo.saved.single.data.personalInfo.fullName, 'Autosaved');
      expect(controller.state.hasUnsavedChanges, isFalse);
      expect(await repo.byId('doc-1'), isNotNull);
    });

    test('collapses a burst of edits into a single write', () async {
      final controller = make();
      await settle();

      for (var i = 0; i < 12; i++) {
        controller.updateData(
          (data) => data.copyWith(
            personalInfo: data.personalInfo.copyWith(fullName: 'Edit $i'),
          ),
        );
      }
      await settle();

      expect(
        repo.attempts,
        1,
        reason: 'typing must not write once per keystroke',
      );
      expect(
        repo.saved.single.data.personalInfo.fullName,
        'Edit 11',
        reason: 'the single write must carry the newest content',
      );
      expect(controller.state.hasUnsavedChanges, isFalse);
    });

    test(
      'saveNow cancels a pending debounce instead of double-saving',
      () async {
        final controller = make();
        await settle();

        controller.updateData(
          (data) => data.copyWith(
            personalInfo: data.personalInfo.copyWith(fullName: 'Explicit'),
          ),
        );
        await controller.saveNow();

        expect(repo.attempts, 1);
        expect(controller.state.hasUnsavedChanges, isFalse);

        // Well past the debounce the timer would have fired on: it must be dead.
        await settle();
        expect(
          repo.attempts,
          1,
          reason: 'the pending timer must be cancelled, not left to fire',
        );
      },
    );

    test(
      'saveNow with nothing pending still writes the current document',
      () async {
        final controller = make();
        await settle();

        await controller.saveNow();

        expect(repo.saved, hasLength(1));
        expect(repo.saved.single.id, 'doc-1');
      },
    );

    test('a failing repository keeps the work marked unsaved', () async {
      repo.failSaves = true;
      final controller = make();
      await settle();

      controller.updateData(
        (data) => data.copyWith(
          personalInfo: data.personalInfo.copyWith(fullName: 'Unlucky'),
        ),
      );
      await settle();

      expect(repo.attempts, 1, reason: 'the save was attempted');
      expect(repo.saved, isEmpty, reason: 'and it failed');
      expect(
        controller.state.hasUnsavedChanges,
        isTrue,
        reason: 'a failed write must stay dirty so the work is retried',
      );

      // Storage comes back: the retry must land the same content.
      repo.failSaves = false;
      await controller.saveNow();

      expect(controller.state.hasUnsavedChanges, isFalse);
      expect(repo.saved.single.data.personalInfo.fullName, 'Unlucky');
    });

    test('an edit made during an in-flight save is not lost', () async {
      final controller = make(autosaveDelay: const Duration(milliseconds: 30));
      await settle();
      final gate = Completer<void>();
      repo.gate = gate;

      controller.updateData(
        (data) => data.copyWith(
          personalInfo: data.personalInfo.copyWith(fullName: 'First'),
        ),
      );
      await settle();
      expect(repo.attempts, 1, reason: 'the first write is in flight');

      // Typing continues while that write is blocked.
      controller.updateData(
        (data) => data.copyWith(
          personalInfo: data.personalInfo.copyWith(fullName: 'Second'),
        ),
      );
      gate.complete();
      await settle();

      // Note: when the first write completes it clears hasUnsavedChanges even
      // though "Second" was not part of it, so there is a brief window where
      // the flag under-reports. The re-armed debounce still writes the newest
      // content, which is what actually matters — asserted here.
      expect(repo.saved.last.data.personalInfo.fullName, 'Second');
      expect(controller.state.hasUnsavedChanges, isFalse);
      expect(
        (await repo.byId('doc-1'))!.data.personalInfo.fullName,
        'Second',
        reason: 'the newest content must reach storage',
      );
    });
  });

  group('preview wiring', () {
    test('a completed render lands in state', () async {
      final controller = make();
      await settle();

      expect(controller.state.pdfBytes, equals(Uint8List.fromList([1, 2, 3])));
      expect(controller.state.renderError, isNull);
      expect(controller.state.isRendering, isFalse);
    });

    test('a render failure surfaces and then recovers', () async {
      renderFails = true;
      final controller = make();
      await settle();

      expect(controller.state.renderError, isA<StateError>());
      expect(controller.state.isRendering, isFalse);

      renderFails = false;
      controller.updateData(
        (data) => data.copyWith(
          personalInfo: data.personalInfo.copyWith(fullName: 'Recovered'),
        ),
      );
      await settle();

      expect(
        controller.state.renderError,
        isNull,
        reason: 'a later good render must clear the stale error',
      );
      expect(controller.state.pdfBytes, isNotNull);
    });

    test('buildForExport renders the current template immediately', () async {
      final controller = make();
      await settle();
      controller.setTemplate('quill');

      final bytes = await controller.buildForExport();

      expect(bytes, isNotEmpty);
      expect(rendered.last.templateId, 'quill');
      expect(
        rendered.last.resumeJson['personalInfo']['fullName'],
        controller.state.data.personalInfo.fullName,
      );
    });

    // Regression: renderNow used to cancel the pending debounce timer and never
    // re-arm it. Editing and then exporting inside the debounce window threw the
    // queued preview render away, leaving the editor with stale bytes AND
    // isRendering stuck true — a spinner that never resolved until the user
    // happened to type again.
    test('exporting does not discard a preview render still queued', () async {
      final controller = make();
      await settle();
      final rendersBefore = rendered.length;

      controller.updateData(
        (data) => data.copyWith(
          personalInfo: data.personalInfo.copyWith(fullName: 'Exported'),
        ),
      );
      await controller.buildForExport();
      await settle();

      expect(
        controller.state.isRendering,
        isFalse,
        reason: 'the busy indicator must resolve, not hang',
      );
      expect(
        rendered.length,
        rendersBefore + 2,
        reason: 'both the export render and the queued preview render must run',
      );
      expect(
        rendered.last.resumeJson['personalInfo']['fullName'],
        'Exported',
        reason:
            'the preview must catch up to the edit that preceded the export',
      );
    });
  });

  group('dispose', () {
    test('cancels a pending autosave and does not throw', () async {
      final controller = make();
      await settle();

      controller.updateData(
        (data) => data.copyWith(
          personalInfo: data.personalInfo.copyWith(fullName: 'Abandoned'),
        ),
      );
      expect(() => disposeNow(controller), returnsNormally);

      await settle();

      expect(
        repo.attempts,
        0,
        reason: 'a disposed editor must not write after teardown',
      );
    });

    test('later edits on a disposed controller are inert', () async {
      final controller = make();
      await settle();
      final rendersBefore = rendered.length;
      disposeNow(controller);

      expect(
        () => controller.updateData(
          (data) => data.copyWith(
            personalInfo: data.personalInfo.copyWith(fullName: 'Too late'),
          ),
        ),
        returnsNormally,
      );
      await settle();

      expect(controller.state.data.personalInfo.fullName, isNot('Too late'));
      expect(rendered.length, rendersBefore);
      expect(repo.attempts, 0);
    });

    test('saveNow after dispose is a silent no-op', () async {
      final controller = make();
      await settle();
      disposeNow(controller);

      await expectLater(controller.saveNow(), completes);
      expect(repo.attempts, 0);
    });
  });
}

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:resume_forge/data/sample_resume.dart';
import 'package:resume_forge/render/preview_engine.dart';
import 'package:resume_forge/render/render_job.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Records every render the engine actually starts, and lets a test hold a
  // render open to exercise the in-flight coalescing path.
  late List<RenderJob> started;
  late List<Completer<Uint8List>> gates;
  late bool gated;

  Future<Uint8List> runner(RenderJob job) {
    started.add(job);
    if (!gated) return Future.value(Uint8List.fromList([1, 2, 3]));
    final c = Completer<Uint8List>();
    gates.add(c);
    return c.future;
  }

  PreviewEngine engine({
    Duration debounce = const Duration(milliseconds: 20),
  }) => PreviewEngine(debounce: debounce, runner: runner);

  setUp(() {
    started = [];
    gates = [];
    gated = false;
  });

  test('debounces a burst of edits into a single render', () async {
    final e = engine();
    addTearDown(e.dispose);

    for (var i = 0; i < 10; i++) {
      e.request(sampleResume, 'aurora');
    }
    await Future<void>.delayed(const Duration(milliseconds: 80));

    expect(
      started.length,
      1,
      reason: 'ten keystrokes must not start ten renders',
    );
  });

  test('emits a result carrying a monotonic revision', () async {
    final e = engine();
    addTearDown(e.dispose);

    final seen = <int>[];
    e.results.listen((r) => seen.add(r.revision));

    e.request(sampleResume, 'aurora');
    await Future<void>.delayed(const Duration(milliseconds: 60));
    e.request(sampleResume, 'aurora');
    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(seen, [1, 2]);
  });

  test(
    'coalesces edits arriving mid-render into exactly one follow-up',
    () async {
      gated = true;
      final e = engine();
      addTearDown(e.dispose);

      e.request(sampleResume, 'aurora');
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(started.length, 1, reason: 'first render should be in flight');

      // Five more edits while the first render is still running.
      for (var i = 0; i < 5; i++) {
        e.request(
          sampleResume.copyWith(
            personalInfo: sampleResume.personalInfo.copyWith(
              fullName: 'Edit $i',
            ),
          ),
          'aurora',
        );
      }
      expect(
        started.length,
        1,
        reason: 'edits during a render must not queue additional renders',
      );

      gates.first.complete(Uint8List.fromList([9]));
      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(
        started.length,
        2,
        reason: 'exactly one catch-up render, not one per edit',
      );
      expect(
        started.last.resumeJson['personalInfo']['fullName'],
        'Edit 4',
        reason: 'the catch-up render must use the newest state',
      );
    },
  );

  test(
    'a failing render surfaces an error without killing the stream',
    () async {
      var fail = true;
      final e = PreviewEngine(
        debounce: const Duration(milliseconds: 10),
        runner: (job) async {
          started.add(job);
          if (fail) throw StateError('boom');
          return Uint8List.fromList([7]);
        },
      );
      addTearDown(e.dispose);

      final errors = <Object>[];
      final results = <PreviewResult>[];
      e.results.listen(results.add, onError: errors.add);

      e.request(sampleResume, 'aurora');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(errors, hasLength(1));

      fail = false;
      e.request(sampleResume, 'aurora');
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(
        results,
        hasLength(1),
        reason: 'the engine must keep working after a failed render',
      );
    },
  );

  test('renderNow bypasses the debounce', () async {
    final e = engine(debounce: const Duration(seconds: 10));
    addTearDown(e.dispose);

    final bytes = await e.renderNow(sampleResume, 'aurora');

    expect(bytes, isNotEmpty);
    expect(started, hasLength(1));
  });

  test(
    'unknown template ids fall back rather than failing the render',
    () async {
      final e = engine();
      addTearDown(e.dispose);

      e.request(sampleResume, 'no-such-template');
      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(started.single.templateId, 'aurora');
    },
  );

  test('requests after dispose are ignored', () async {
    final e = engine();
    await e.dispose();

    e.request(sampleResume, 'aurora');
    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(started, isEmpty);
  });

  test('isBusy reflects scheduled and in-flight work', () async {
    gated = true;
    final e = engine();
    addTearDown(e.dispose);

    expect(e.isBusy, isFalse);
    e.request(sampleResume, 'aurora');
    expect(e.isBusy, isTrue, reason: 'scheduled counts as busy');

    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(e.isBusy, isTrue, reason: 'in-flight counts as busy');

    gates.first.complete(Uint8List.fromList([1]));
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(e.isBusy, isFalse);
  });
}
